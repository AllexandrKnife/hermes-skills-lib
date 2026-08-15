# Раздельная политика per-device на OpenWrt + sing-box (проверено 08.2026)

> ⚠️ ВНИМАНИЕ (итог сессии 08.2026): ручная схема из этого файла (auto_route:false +
> таблица 100 + ip rule + зона tun) ПРОВАЛЕНА — телефон так и не получил интернет
> через туннель (ответы не возвращались). РАБОЧИЙ способ — `auto_route: true` +
> `source_ip_cidr` внутри конфига sing-box, см. SKILL.md «Раздельная политика
> per-device». Этот файл оставлен как ДИАГНОСТИЧЕСКАЯ ЗАПИСЬ: разбор причин провала
> (fw4 drop, masq, filter_aaaa, слетающие маршруты) и симптомы из conntrack/nftables
> полезны для будущих разборов. НЕ применять разделы 1-5 и A-B как рабочую процедуру.

Ситуация: Cudy WR3000S (OpenWrt 25.12.5, MT7981) в WISP-режиме (Wi-Fi клиент Keenetic,
phy1-sta0 → 192.168.1.1, адрес 192.168.1.136). sing-box tun (singtun, 172.19.0.1/30)
VLESS+Reality на 45.134.15.185:443. Пользователь хочет: НАЗВАННЫЕ устройства через
туннель, остальные напрямую через Keenetic.

## Проблема, которую решает

- `auto_route: true` заворачивает ВЕСЬ трафик роутера в tun. При этом sing-box может
  не добавить маршруты в свою таблицу (на этой сборке таблица 2022 оставалась ПУСТОЙ
  при auto_route=true) → пакеты уходят в tun и теряются: пинг 8.8.8.8 отвечает
  локально за 0.2 мс с TTL 64 (НЕ интернет!), клиенты видят «нет доступа к интернету».
- Нужна ручная политика: ip rule по src-IP устройства.

## Процедура (проверено до уровня маршрутизации)

### 1. Отключить auto_route в конфиге sing-box
```sh
sed -i 's/"auto_route": true/"auto_route": false/' /etc/sing-box/config.json
/usr/bin/sing-box check -c /etc/sing-box/config.json   # rc=0
/etc/init.d/sing-box restart
# ошибка «ubus call service delete ... Not found» при restart — НОРМА, процесс перезапустился:
ps w | grep sing-box | grep -v grep
```

### 2. Создать таблицу 100 и правила (в живую, для проверки)
```sh
ip route add default dev singtun table 100
ip rule add from 192.168.10.223 lookup 100          # телефон Xiaomi — через туннель
ip rule add iif singtun lookup main                  # ответы из tun -> основная таблица
ip rule add to 45.134.15.185 lookup main             # трафик к серверу Reality не заворачивать
ip rule show   # 0 local; 32764 iif singtun main; 32765 from <ip> 100; 32766 main; 32767 default
```

### 3. Закрепить IP за устройством (иначе DHCP сменит адрес и правило умрёт)
```sh
uci add dhcp host
uci set dhcp.@host[-1].name="xiaomi-phone"
uci set dhcp.@host[-1].mac="5a:22:9a:df:18:f0"      # MAC из ip neigh / /proc/net/arp
uci set dhcp.@host[-1].ip="192.168.10.223"
uci commit dhcp
```

### 4. Сохранить в автозагрузку (/etc/rc.local)
```sh
# Политика: телефон через туннель, остальные напрямую
sleep 3   # ждём, пока sing-box создаст singtun
ip route add default dev singtun table 100 2>/dev/null
ip rule add from 192.168.10.223 lookup 100 2>/dev/null
ip rule add iif singtun lookup main 2>/dev/null
ip rule add to 45.134.15.185 lookup main 2>/dev/null
exit 0
```

### 5. Проверка без клиента
```sh
# Должно показать dev singtun  (= через туннель):
ip route get 8.8.8.8 from 192.168.10.223 iif br-lan
# Должно показать via 192.168.1.1 dev phy1-sta0  (= напрямую, мимо туннеля):
ip route get 8.8.8.8 from 192.168.10.149 iif br-lan
```

### 6. Финальный egress-тест — ТОЛЬКО с реального клиента
Попросить пользователя открыть 2ip.ru на телефоне: IP должен быть 45.134.15.185.
Пинг с роутера с чужим src НЕ работает: `ping -I 192.168.10.223 8.8.8.8` →
«can't set multicast source interface». Счётчики tun: /sys/class/net/singtun/statistics/{rx,tx}_packets.

## Ключевые диагностические факты (08.2026)

- Пинг 8.8.8.8 с роутера 0.2 мс TTL 64 = локальный ответ, НЕ интернет. Настоящий
  интернет: TTL ~106, ~56 мс (через Keenetic WISP). Не доверять пингу с роутера.
- busybox wget на 25.12.5 падает «Operation not permitted» и на http, и на https —
  для проверки egress не годится; только клиентское устройство.
- `pgrep -x sing-box` на этой сборке пуст при работающем процессе — использовать
  `ps w | grep sing-box | grep -v grep` или `/etc/init.d/sing-box status`.
- После `uci set network.wwan.ipv6="0"` нужен `ifup wwan` (network reload
  недостаточно: wwan остаётся up:false, IPv4 не переполучается).
- Keenetic видит Cudy дважды (IPv4+IPv6) пока wwan не перезапущен — после ifup wwan
  глобальных IPv6 нет, только fe80 (норма).

## Firewall: регистрация singtun + зона БЕЗ masq (КРИТИЧНО, 08.2026)

Даже при идеальных маршрутах телефон остаётся без интернета, если фаервол не
пропускает трафик в туннель и маскирует адреса. Два обязательных шага:

### A. Зарегистрировать singtun как сетевой интерфейс в UCI
```sh
uci set network.singtun=interface
uci set network.singtun.proto="none"
uci set network.singtun.device="singtun"
uci commit network
/etc/init.d/network reload && /etc/init.d/firewall restart
```
Проверка: `nft list chain inet fw4 accept_to_wan` — до регистрации там только
`oifname { "wan", "phy1-sta0" }` (трафик в singtun ДРОПАЕТСЯ, forward policy drop);
после — `oifname { "wan", "singtun", "phy1-sta0" }`. Без этого шага трафик
устройства в туннель молча блокируется фаерволом — классический симптом «маршруты
правильные (ip route get → dev singtun), а интернета нет».

### B. Вынести singtun из зоны wan в отдельную зону БЕЗ masquerade
Зона wan имеет `masq='1'` — она подменяет src-адрес клиента на адрес роутера ДО
входа в туннель, и обратные пакеты из tun не находят клиента. Симптом в conntrack:
`src=192.168.10.223 dst=... [UNREPLIED] src=... dst=192.168.10.1` (обратная пара
указывает на роутер, а не на телефон).
```sh
uci del_list firewall.@zone[1].network="singtun"   # убрать из wan
uci add firewall zone
uci set firewall.@zone[-1].name="tun"
uci set firewall.@zone[-1].network="singtun"
uci set firewall.@zone[-1].input="ACCEPT"
uci set firewall.@zone[-1].output="ACCEPT"
uci set firewall.@zone[-1].forward="ACCEPT"
uci set firewall.@zone[-1].masq="0"
uci add firewall forwarding
uci set firewall.@forwarding[-1].src="lan"
uci set firewall.@forwarding[-1].dest="tun"
uci commit firewall
/etc/init.d/firewall restart
```
Проверка: `nft list chain inet fw4 forward_lan` → есть `jump accept_to_tun`;
`uci show firewall | grep -A2 "name='tun'"` → masq='0'.

### C. Диагностика через conntrack (когда «нет интернета на телефоне»)
```sh
cat /proc/net/nf_conntrack | grep 192.168.10.223
# SYN_SENT ... [UNREPLIED] = пакеты уходят, ответы не приходят
# обратная пара с dst=192.168.10.1 (не .223) = masq ломает путь — см. шаг B
cat /proc/net/nf_conntrack | grep -v ":53 " | grep 192.168.10.223   # без DNS-шума
# очистка старых записей после правки firewall:
echo f > /proc/net/nf_conntrack
```

### D. DNS: filter_aaaa (телефон виснет на IPv6-ответах)
IPv6 на роутере отключён, но dnsmasq продолжает отдавать AAAA (IPv6-адреса сайтов) —
телефон пытается идти по IPv6 и молча висит. Включить фильтр:
```sh
uci set dhcp.@dnsmasq[0].filter_aaaa="1"
uci commit dhcp
/etc/init.d/dnsmasq restart
```
Проверка до/после: `nslookup -type=AAAA google.com` (после фильтра ответ пуст).

### E. Маршрут таблицы 100 — сохранить через UCI (переживёт network reload)
Ручной `ip route add default dev singtun table 100` СНОСИТСЯ любым network reload.
Долговременно — через UCI:
```sh
uci set network.vpnroute=route
uci set network.vpnroute.interface="singtun"
uci set network.vpnroute.target="0.0.0.0"
uci set network.vpnroute.netmask="0.0.0.0"
uci set network.vpnroute.table="100"
uci commit network
```
После этого маршрут восстанавливается netifd при reload; rc.local и init-хук
sing-box остаются страховкой на случай пересоздания singtun рестартом туннеля.
