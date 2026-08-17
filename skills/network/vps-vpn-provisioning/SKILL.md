---
name: vps-vpn-provisioning
version: 1.0.0
description: "Use when provisioning VPN/proxy services on user's VPS."
critic_status: done
---

# VPS VPN/Proxy provisioning (инфраструктура пользователя)

## Когда использовать
- Установка sing-box на VPS через скрипт yonggekkk/sing-box-yg (sb.sh)
- Установка WireGuard-сервера на VPS для клиента Keenetic (или другого роутера)
- Замена/обновление скрипта sb.sh (китайская → русская версия)
- Привязка DNS туннеля к своему AdGuardHome

## Общая схема
VPS пользователя: root/VPS_ROOT_PASSWORD_PLACEHOLDER (реестр в памяти). Выходной интерфейс — ens18; проверять через /proc/net/route (`ip` может отсутствовать, см. Pitfalls).
Типовой стек одного VPS: sing-box (прокси) + WireGuard (туннель роутера); DNS — AdGuardHome+unbound на отдельном VPS (45.134.15.185, слушает *:53).

## 1. Установка sing-box (sb.sh, yonggekkk)
Скрипт интерактивный — запускать через background PTY + process submit, НЕ в foreground:
```
terminal(background=true, pty=true, command="sshpass -p '...' ssh -t -o StrictHostKeyChecking=no root@IP 'bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)'")
process(action=poll/wait) → process(action=submit, data="...")
```
Полная последовательность промптов и ответов: references/sing-box-yg-install-flow.md
Ключевое:
- debconf iptables-persistent «Save current IPv4/IPv6 rules?» → no / no
- needrestart «Which services should be restarted?» → 9 (none) — всплывает ПОСЛЕ КАЖДОГО батча apt, отвечать повторно
- tzdata: Europe (8) → Berlin (7)
- Меню: 1 (установка) → 1 (открыть порты/снять фаервол) → 1 (последний стабильный kernel) → 1 (самоподписанный cert, не ACME) → 1 (авто-случайные порты)
- Скрипт самоустанавливается в /usr/bin/sb; конфиг /etc/s-box/sb.json; сервис sing-box.service (enabled)
- После установки: systemctl is-active sing-box; порты из sb.json (grep listen_port)
- Путь к конфигу, если неизвестен: systemctl cat sing-box | grep ExecStart (обычно /etc/s-box/sing-box run -c /etc/s-box/sb.json). Список протоколов/портов: jq -r '.inbounds[] | "\(.type) port=\(.listen_port)"' /etc/s-box/sb.json. Стандартный набор sbyg: VLESS, VMess, Hysteria2, Tuic, AnyTLS (порты авто-случайные); на всех нодах рядом mita (11000-11005), AdGuardHome *:53 и :3000, unbound 127.0.0.1:5353, webmin 10000, fail2ban, cron «0 1 * * * systemctl restart sing-box»

## 2. Русская версия sb.sh
По умолчанию ставится китайская. Русская версия — на VPS 45.134.15.185: /usr/bin/sb (sha256 bbf9c98d3e1f9d96ed3c127b54014d9680969bfb903a6a94c3388a0a306e687e).
Замена с бэкапом (прямой pipe VPS→VPS, без промежуточного файла):
```
ssh B 'cp /usr/bin/sb /usr/bin/sb.bak.cn'
ssh 45.134.15.185 'cat /usr/bin/sb' | ssh B 'cat > /usr/bin/sb && chmod 755 /usr/bin/sb && sha256sum /usr/bin/sb'
```
Проверка: bash -n; grep русских строк меню («Установка необходимых зависимостей…»); sha256 == источник.
Откат: mv /usr/bin/sb.bak.cn /usr/bin/sb.

## 3. WireGuard-сервер для Keenetic
Если пользователь просит уточнения — сначала вопросы (скилл ask-first): сценарий (роутер/клиент), порт (нестандартный, НЕ 443), подсеть, правило «WSL к WG не подключается — только роутер».
Порядок:
1. apt-get install -y wireguard; modprobe wireguard (модуль встроен в ядро 5.15)
2. Ключи: umask 077; wg genkey → server.key, client.key; wg pubkey; chmod 600
3. Конфиг сервера: templates/wireguard-server.conf (подставить ключи, ens18, MASQUERADE, MTU 1420)
4. sysctl: echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf; sysctl -p
5. systemctl enable wg-quick@wg0; systemctl start wg-quick@wg0
6. Проверка: wg show (peer, listening port); порт UDP снаружи: timeout 8 bash -c 'echo t > /dev/udp/IP/PORT'
7. Конфиг клиента Keenetic: templates/keenetic-wg-client.conf — сохранить на VPS /root/ И копией в WSL /root/ (пользователь просит обе копии), chmod 600 у обеих

## 4. DNS туннеля
Для полного туннеля (AllowedIPs 0.0.0.0/0) секция DNS в клиентском конфиге ОБЯЗАТЕЛЬНА. У пользователя: AdGuardHome+unbound на 45.134.15.185.
Проверить ДО установки в конфиг:
- на 185: ss -ulpn | grep ":53 " (слушает *:53, UDP+TCP)
- внешний резолв: python3 UDP-запрос example.com к 45.134.15.185:53 → ответ с ANCOUNT>0
DNS = 45.134.15.185 → домашняя сеть получает ad-block + unbound через туннель.

## Pitfalls
- autoremove может снести iproute2 → wg-quick падает «ip: command not found» → apt-get install -y iproute2 (проверять which ip после чисток)
- Ручной `wg-quick up` НЕ регистрируется в systemd: is-active показывает inactive. Поднимать только через systemctl start wg-quick@wg0 (сначала down, если уже поднят руками)
- Порт WG не должен пересекаться с портами sing-box (смотреть listen_port в /etc/s-box/sb.json) и не должен быть 443/51820 без запроса
- Приватные ключи и клиентский конфиг — chmod 600, не логировать содержимое
- После правки конфига клиента на VPS синхронизировать копию в WSL /root/
- ss отсутствует на минимальных VPS — проверять порты через /proc/net/udp и /proc/net/tcp (awk + strtonum("0x..."))
- UDP-порты sing-box (hy2, tuic) в /proc/net/tcp не видны — это норм

## Related
- homelab-wireguard-vpn (ecc) — общая теория WG, split/full tunnel, ключи
- vpn-egress-tunnel / wsl-vpn-on-demand — WSL-клиентская сторона (WSL к WG не подключается!)
- vps-adguard-dns-integration — AdGuardHome на VPS
