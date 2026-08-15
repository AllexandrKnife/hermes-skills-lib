# WireGuard на VPS (соседствует с sing-box) + клиент Keenetic

Сценарий: VPS с уже работающим sing-box; WG-сервер для домашнего роутера Keenetic
(полный туннель). WSL к WG-интерфейсам НЕ подключается (правило пользователя) —
только роутер. Отработано на 5.39.255.242: порт 51871, подсеть 10.7.0.0/24.

## Установка
```
apt-get install -y wireguard        # модуль встроен в ядро 5.15 (modprobe wireguard OK)
apt-get install -y iproute2         # см. Pitfalls — autoremove мог его снести
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf && sysctl -p /etc/sysctl.d/99-wireguard.conf
```

## Генерация ключей (на сервере, umask 077)
```
cd /etc/wireguard
wg genkey > server.key;  wg pubkey < server.key  > server.pub
wg genkey > keenetic.key; wg pubkey < keenetic.key > keenetic.pub
chmod 600 server.key keenetic.key
```

## /etc/wireguard/wg0.conf (сервер)
```
[Interface]
Address = 10.7.0.1/24
ListenPort = 51871                  # нестандартный, не 443, не из портов sing-box
PrivateKey = <server.key>
MTU = 1420
PostUp = iptables -A FORWARD -i wg0 -o ens18 -j ACCEPT
PostUp = iptables -A FORWARD -i ens18 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -o ens18 -j ACCEPT
PostDown = iptables -D FORWARD -i ens18 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ens18 -j MASQUERADE

[Peer]                               # Keenetic
PublicKey = <keenetic.pub>
AllowedIPs = 10.7.0.2/32
PersistentKeepalive = 25
```
- Наружу-интерфейс: ens18 (проверять `/proc/net/route`, т.к. `ip` может отсутствовать)
- Подсеть 10.7.0.0/24 — 10.8.0.0/24 у пользователя «занята», брать другую

## Запуск — ТОЛЬКО через systemctl
```
systemctl enable wg-quick@wg0 && systemctl start wg-quick@wg0
```
Ручной `wg-quick up wg0` поднимает интерфейс, но systemd считает юнит inactive
(не регистрируется) — `systemctl is-active` соврёт. Для перезапуска: down через
systemctl, потом start.

## Поля для Keenetic (веб-интерфейс: Другие подключения → VPN-клиент → WireGuard)
- IP-адрес: 10.7.0.2, маска /24
- Приватный ключ: <keenetic.key>
- Публичный ключ (сервера): <server.pub>
- Сервер (Endpoint): <ip_vps>:51871
- Разрешённые сети: 0.0.0.0/0 (полный туннель — весь трафик роутера через VPS)
- Keepalive: 25 сек, MTU: 1420

## Проверка
- `systemctl is-active wg-quick@wg0` — active
- `wg show wg0` — после подключения роутера появляется «latest handshake»
- UDP-порт: `/proc/net/udp` → `awk 'NR>1 {split($2,a,":"); if (strtonum("0x"a[2])==51871) print "UDP OK"}'` (ss/netstat могут отсутствовать)
- Снаружи: `bash -c 'echo test > /dev/udp/<ip>/<port>'`

## Pitfalls
- **autoremove снёс iproute2**: после очистки системы `ip` пропадает → wg-quick падает
  `line 32: ip: command not found`. Лечится `apt-get install -y iproute2` до `wg-quick up`.
- hy2/tuic-порты sing-box — UDP (QUIC), в /proc/net/tcp их нет; не путать с «не слушает».
- wg0 слушает `::` (dual-stack) — UDP 51871 виден и на 0.0.0.0, и на [::].
