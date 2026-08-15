# Миграция WireGuard-туннеля с Keenetic на Cudy (кейс GeR, 08.2026)

Цель: перенести WG-туннель (у пользователя «GeR») с Keenetic на OpenWrt-роутер (Cudy) с раздельной политикой per-device. Процедура снятия конфига проверена вживую; разворачивание на Cudy — по шагам ниже.

## Шаг 1. Снять WG-конфиг с Keenetic (telnet CLI)
- Вход: `KEEN_HOST=<ip> KEEN_PASS=<пароль> python3 <skill>/scripts/keen_telnet_cli.py 'show running-config'`
- ВАЖНО: Keenetic может быть не на 192.168.1.1, а в чужой подсети (кейс: Keenetic — WISP-клиент Cudy, адрес 192.168.10.234). Слушать пользователя, какой адрес использовать, не гадать.
- В running-config туннель выглядит так (пример GeR):
```
interface Wireguard0
    description GeR
    security-level public
    ip address 10.8.1.3 255.255.255.255
    ip mtu 1416
    ip global 32067
    ip tcp adjust-mss pmtu
    wireguard peer CdzLgM8VoeP6K5d2mgPiXyZenXuPjZDWch2PzHXYjGA= !GeR
        endpoint 45.134.15.185:37487
        keepalive-interval 25
        preshared-key Ulon67Y0EsFNhyXePTekzjc9AJ5bAxsvdpvDQPBx29U=
        allow-ips 0.0.0.0 0.0.0.0
        allow-ips :: 0
        connect
    !
    up
```
- Что есть в конфиге Keenetic: peer PublicKey (ключ СЕРВЕРА), endpoint, keepalive, preshared-key, allow-ips, адрес клиента (ip address), mtu, приоритет (ip global).
- ЧЕГО НЕТ: приватный ключ клиента (Keenetic его не отдаёт) и собственный публичный ключ роутера. Поэтому для нового устройства — генерировать НОВУЮ пару ключей, не пытаться вытащить старую.

## Шаг 2. Найти серверную сторону (docker на VPS)
- Endpoint-порт искать на VPS: `ss -tlnup | grep <port>` → `docker-proxy` → контейнер.
- Кейс: порт 37487 → контейнер `amnezia-wireguard` (обычный WireGuard! НЕ AmneziaWG — AWG-контейнер отдельный, `amnezia-awg`, другой порт 37409).
- Конфиг сервера: `docker exec <container> cat /opt/amnezia/wireguard/wg0.conf` (НЕ /etc/wireguard — там пусто):
```
[Interface]
PrivateKey = <ключ сервера>
Address = 10.8.1.0/24
ListenPort = 37487
[Peer]  # 10.8.1.1 .. 10.8.1.6 — уже заняты
PublicKey = <ключ клиента>
PresharedKey = <общий>
AllowedIPs = 10.8.1.3/32
```
- Маппинг клиентов: AllowedIPs 10.8.1.x/32 ↔ ip address в конфиге Keenetic. GeR = 10.8.1.3.

## Шаг 3. Подготовить нового клиента (Cudy)
1. Свободный адрес из подсети сервера (кейс: 10.8.1.7).
2. Генерация ключей на WSL (wg из wireguard-tools):
   - `PRIV=$(wg genkey); PUB=$(echo "$PRIV" | wg pubkey)` — публичный ключ Cudy пойдёт на сервер.
3. Клиентский конфиг (формат .conf, импортируется в OpenWrt/клиенты):
```
[Interface]
PrivateKey = <новый приватный Cudy>
Address = 10.8.1.7/32
DNS = 1.1.1.1

[Peer]
PublicKey = <ключ сервера из конфига Keenetic>
PresharedKey = <общий preshared из Keenetic>
Endpoint = <ip сервера>:<порт>
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```
4. Добавить пир на сервер: новый блок [Peer] с PublicKey Cudy, PresharedKey (общий), AllowedIPs = 10.8.1.7/32 → применить (`docker exec ... wg addconf` или рестарт контейнера).
- Питфолл: пока пир не добавлен на сервер, клиент «молча» не работает (no response) — конфиг на клиенте валиден, но сервер его не знает.

## Шаг 4. Развёртывание на Cudy
- Стоковая прошивка Cudy VPN УМЕЕТ (проверено 08.08.2026): на главной странице LuCI (System Status) есть секция VPN — WireGuard Client. Пользователь поднял WG GeR на стоке (адрес 10.8.1.7) через веб-интерфейс, телефон через Wi-Fi Cudy показал внешний IP 45.134.15.185 — туннель работает. OpenWrt для обычного WG НЕ нужен.
- ГДЕ НАСТРАИВАТЬ на стоке: System Status → VPN → вкладка Settings (раздел в меню Advanced Settings НЕ появляется — VPN живёт только в System Status). Поля формы WireGuard Client:
  - Interface: IP Address (10.8.1.7), Subnet Mask (255.255.255.0), Private Key, MTU (1420)
  - Peer: Public Key (ключ СЕРВЕРА CdzLgM8...), Endpoint Host (45.134.15.185), Endpoint Port (37487), Preshared Key
  - Default Rule: Allow all devices (все через туннель) / Ban all devices — аналог раздельной политики
  - VPN Policy: Disable / VPN kill switch / Domain / Remote Subnet
  - Configuration File: импорт готового .conf (Browse)
  - Save & Apply → Status показывает Connected + Tunnel IP.
- ПРИМЕЧАНИЕ: поле Default Rule = «Allow all devices» означает ВЕСЬ Wi-Fi Cudy через туннель; «кому VPN, кому нет» решается ВЫБОРОМ СЕТИ (Cudy-B014 vs Keenetic-0180), не политикой внутри Cudy. Схема «два Wi-Fi = выбор VPN» — рабочая, подтверждена.
- OpenWrt на Cudy требуется только для VLESS/Reality (sing-box) или раздельной политики внутри одной сети; для схемы «два Wi-Fi = выбор VPN» сток достаточен.
- На OpenWrt (если всё же нужен): пакет wireguard-tools + kmod-wireguard, uci network interface (proto wireguard) + peer, или импорт .conf.
- Раздельная политика per-device — через source_ip_cidr в sing-box (см. references/per-device-auto-route.md) либо классический ip rule + таблица.

## Сохранение файла пользователю (Windows Desktop)
- Рабочий стол Windows из WSL: `/mnt/c/Users/<user>/Desktop/` (в кейсе dkolchin).
- Имя файла — как просит пользователь (кейс: «Туннель GeR.conf»); write_file с кириллицей в имени работает.
