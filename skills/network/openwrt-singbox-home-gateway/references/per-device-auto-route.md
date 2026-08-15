# Per-device политика: auto_route:true + source_ip_cidr (РАБОЧИЙ способ, 08.2026)

Рабочая схема разделения «названные устройства через туннель, остальные напрямую».
Пришла на смену ПРОВАЛЕННОЙ ручной схеме (см. per-device-policy.md — диагностика
провала). Пользователь явно потребовал НЕ весь трафик через туннель.

## Принцип

- `auto_route: true` остаётся включённым: sing-box сам заворачивает весь LAN-трафик
  в tun (создаёт таблицу 2022 и ip rule 8997-9010, управляет ими сам).
- Выбор «кто через туннель» — правилами ВНУТРИ конфига sing-box (route.rules),
  НЕ ручными ip rule / таблицами.
- `final: "direct"` → все устройства, кроме перечисленных в source_ip_cidr, идут
  напрямую через Keenetic. `final: "vless-reality"` → наоборот (все через туннель,
  кроме direct-исключений).

## Конфиг /etc/sing-box/config.json (фрагмент)

```json
"route": {
  "final": "direct",
  "rules": [
    {
      "ip_cidr": ["45.134.15.185/32", "127.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
      "outbound": "direct"
    },
    {
      "source_ip_cidr": ["192.168.10.223/32"],
      "outbound": "vless-reality"
    }
  ]
}
```

- Первое правило: локальные сети и САМ СЕРВЕР Reality — direct (иначе петля).
- Второе правило: source_ip_cidr = IP устройства → через туннель. По одному правилу
  на устройство или подсеть.
- Порядок правил важен: специфичные (source_ip_cidr) — ПОСЛЕ локальных direct,
  иначе локальный трафик устройства уйдёт в туннель.

## Процедура

1. Править JSON НА WSL (python3), не на роутере — на роутере python3 ОТСУТСТВУЕТ:
   ```sh
   scp root@192.168.10.1:/etc/sing-box/config.json /tmp/cfg.json
   # python3: json.load → правки → json.dump(indent=2)
   scp /tmp/cfg.json root@192.168.10.1:/etc/sing-box/config.json
   ```
2. Проверка и рестарт (ПЕРЕД рестартом killall — restart не всегда убивает старый
   процесс, плодятся дубли ip rule):
   ```sh
   /usr/bin/sing-box check -c /etc/sing-box/config.json   # rc=0
   killall sing-box; sleep 2
   /etc/init.d/sing-box start
   sleep 4
   ps w | grep sing-box | grep -v grep   # ровно 1 процесс
   ```
3. Закрепить IP устройства статически (правило по IP умрёт при смене лизы):
   ```sh
   uci add dhcp host
   uci set dhcp.@host[-1].name="xiaomi-phone"
   uci set dhcp.@host[-1].mac="5a:22:9a:df:18:f0"   # из ip neigh / /proc/net/arp
   uci set dhcp.@host[-1].ip="192.168.10.223"
   uci commit dhcp
   ```

## Проверки

- Без клиента: `ip route get 8.8.8.8 from <ip> iif br-lan` → `dev singtun` = через
  туннель; `via 192.168.1.1 dev phy1-sta0` = напрямую.
- Финальный egress-тест ТОЛЬКО с устройства: 2ip.ru на телефоне → IP 45.134.15.185.
- НЕ полагаться на: `ping 8.8.8.8` с роутера (0.2 мс TTL 64 = локальный ответ,
  НЕ интернет; настоящий — ~56 мс TTL ~106), busybox wget (падает «Operation not
  permitted» и на http), `pgrep -x sing-box` (пусто при живом процессе — использовать
  `ps w | grep sing-box | grep -v grep`).

## Питфоллы

- auto_route:true + ручные ip rule из старой схемы — конфликт: sing-box плодит
  дубли (pref 8994-8998 рядом со штатными 8997-9010). При переходе: убрать блок
  восстановления из /etc/init.d/sing-box И /etc/rc.local, `ip rule del pref 8994..8998`,
  `ip route flush table 100`.
- `restart` шумит «ubus call service delete ... Not found» — норма.
- После `uci set network.wwan.ipv6="0"` — обязательно `ifup wwan` (reload
  недостаточно). Keenetic видит Cudy дважды (IPv4+IPv6), пока wwan не перезапущен.
- DNS отдаёт AAAA при отключённом IPv6 → телефон виснет: `uci set
  dhcp.@dnsmasq[0].filter_aaaa="1"` + рестарт dnsmasq.
- Названия интерфейсов: tun = singtun, WISP-клиент = phy1-sta0/wwan, LAN = br-lan.
