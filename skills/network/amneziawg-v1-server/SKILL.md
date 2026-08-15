---
name: amneziawg-v1-server
version: 1.0.0
description: "Use when WG блокируется DPI — AWG v1.0 сервер + Keenetic."
critic_status: done
---

# AmneziaWG v1.0 server (клиенты v1.0: Keenetic 4.3.4+)

## Когда использовать
WireGuard блокируется DPI/TSPU (туннель встаёт, хендшейк есть, но трафик глохнет/ретрансмиссии) — нужна обфускация AmneziaWG v1.0. Совместим с KeeneticOS 4.3.4+ и 5.0.x (v1.5/2.0 требуют 5.1 Alpha 3+ и НЕсовместимы с v1.0-сервером).

## Ключевые факты
- Модуль: amnezia-vpn/amneziawg-linux-kernel-module. Теги v1.0.YYYYMMDD — протокол v1.0 (поддерживается параллельно с v3.0). НЕ путать с v3.0 (новый протокол).
- Инструменты: amnezia-vpn/amneziawg-tools — готовые бинарники в релизах (ubuntu-22.04-amneziawg-tools.zip).
- Конфиг awg-quick ищет в /etc/amnezia/amneziawg/ (НЕ /etc/wireguard/).
- Параметры Jc/Jmin/Jmax/S1/S2/H1-H4 должны совпадать на сервере и клиенте.
- H1-H4: u32 десятичные (можно диапазон "a-b" — ядро берёт случайное в диапазоне).

## Установка сервера (Ubuntu 22.04, ядро 5.15)
1. Исходники: github.com/amnezia-vpn/amneziawg-linux-kernel-module/archive/refs/tags/v1.0.20260725.tar.gz
2. ПАТЧ для 5.15: в src/compat/compat.h условие
   `#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 1, 91) && !defined(ISUBUNTU2004) && !defined(ISUBUNTU2204) && !defined(ISRHEL9)`
   → убрать `&& !defined(ISUBUNTU2204)` (Ubuntu 5.15 НЕ имеет timer_delete, а compat ошибочно исключает shim). Без патча: ошибка implicit declaration of timer_delete.
3. cd src && make && make install (нужны build-essential + linux-headers-$(uname -r))
4. Заменить стандартный модуль:
   `echo "blacklist wireguard" > /etc/modprobe.d/blacklist-wireguard.conf; rmmod wireguard; modprobe amneziawg`
5. awg/awg-quick из релиза tools → /usr/local/bin (chmod +x)
6. Конфиг /etc/amnezia/amneziawg/awg0.conf (шаблон ниже), chmod 600
7. systemd: скопировать /lib/systemd/system/wg-quick@.service как awg-quick@.service, заменив ExecStart/ExecStop на /usr/local/bin/awg-quick. enable+start.

## Конфиг сервера (шаблон)
```
[Interface]
PrivateKey = <server.key>
Address = 10.7.0.1/24
ListenPort = 51871
MTU = 1420
Jc = 5
Jmin = 30
Jmax = 50
S1 = 16
S2 = 16
H1 = 1234567890
H2 = 987654321
H3 = 555555555
H4 = 111111111
PostUp = iptables -A FORWARD -i awg0 -o ens18 -j ACCEPT
PostUp = iptables -A FORWARD -i ens18 -o awg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE
PostDown = iptables -D FORWARD -i awg0 -o ens18 -j ACCEPT
PostDown = iptables -D FORWARD -i ens18 -o awg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ens18 -j MASQUERADE

[Peer]
PublicKey = <клиент>
PresharedKey = <wg genpsk>
AllowedIPs = 10.7.0.2/32
PersistentKeepalive = 25
```

## Клиент Keenetic
- Конфиг клиента: [Interface] (Address 10.7.0.2/24, DNS = <свой DNS>, PrivateKey, Jc..H4, MTU) + [Peer] (PublicKey сервера, PresharedKey, AllowedIPs 0.0.0.0/0, Endpoint = ip:port, PersistentKeepalive 25).
- Импорт через RCI: POST /rci/interface/wireguard/import {"import": <base64 файла>, "name": "", "filename": "x.conf"} (auth — keenetic-router-admin). Ответ: {"created": "WireguardN", "intersects": ...}. В running-config появляется `wireguard asc Jc Jmin Jmax S1 S2 H1 H2 H3 H4`.
- После импорта ОБЯЗАТЕЛЬНО (CLI): `interface WireguardN` → `ip global <приоритет>` (иначе не попадает в ip policy: ошибка "no such global interface") → `up` → exit; `ip policy PolicyN` → `permit global WireguardN` → exit; `interface WireguardN` → `ip name-server <dns> "" on WireguardN` (синтаксис с `"" on <iface>`!) → exit; `system configuration save`.
- Приоритет: МЕНЬШЕ значение ip global = ВЫШЕ приоритет (16033 > 32067 выигрывает 16033).
- Диагностика выбора туннеля: в `ip policy PolicyN` несколько `permit global` — при подозрении, что трафик идёт не туда, оставить один разрешённый интерфейс (A/B-тест).

## Проверка
- `awg show awg0` — видны jc/jmin/jmax/s1/s2/h1-h4, handshake, transfer.
- Порт: `cat /proc/net/udp | awk 'NR>1 {split($2,a,":"); if (strtonum("0x"a[2])==51871) print "LISTEN"}'`.

## Pitfalls
- НЕ использовать bivlked/amneziawg-installer — это AWG 2.0 (несовместим с Keenetic 5.0.8).
- Docker amneziavpn/amnezia-wg (2023) содержит wireguard-go, а не awg — для v1.0 на хосте нужен модуль ядра.
- wg-quick НЕ работает с модулем amneziawg (link kind "amneziawg") — только awg-quick.
- Тег v1.0.20241112 требует полный исходник ядра — не брать, проще пропатчить свежий тег.
- Ключи Curve25519 взаимозаменяемы: wg genkey/wg pubkey годятся для awg.
