# Per-VPS quirks — AdGuardHome + VPN integration

## 46.30.47.120 (Netherlands, Eurodir)
- **OS**: Debian 12
- **VPN stack**: native WireGuard (port 54711), sing-box, Docker Amnezia
- **systemd-resolved**: active, 127.0.0.53:53, не блокирует 0.0.0.0:53
- **AdGuardHome**: установлен с нуля, штатный systemd
- **amnezia-dns**: был на amnezia-dns-net (172.29.172.254), удалён
- **iptables**: 4 правила (172.29.172.0/24, 172.17.0.0/16, wg0, 172.29.172.254)
- **dig**: есть (dnsutils установлен)
- **Особенности**: WG клиентов 11 штук, у всех AllowedIPs = 0.0.0.0/0

## 45.134.15.185 (Frankfurt, Firstbyte)
- **OS**: Ubuntu 22.04
- **VPN stack**: sing-box (5 протоколов), Docker Amnezia AWG
- **AdGuardHome**: был установлен ранее, systemd
- **Проблема**: при настройке unbound обнаружился старый процесс AdGuardHome (PID 10729), запущенный вручную без systemd, державший порт 53
- **Решение**: `kill` старого процесса, `systemctl restart AdGuardHome`
- **Особенности**: this VPS runs Hermes Agent Gateway

## 87.121.38.60 (babayka.duckdns.org, Россия)
- **OS**: Ubuntu 22.04 minimal
- **VPN stack**: sing-box, Docker Amnezia (xray на 443/HTTPS!)
- **systemd-resolved**: активен, **блокирует TCP 0.0.0.0:53** несмотря на то что слушает 127.0.0.53
- **Решение**: `DNSStubListener=no` + рестарт systemd-resolved
- **Нет dig/nslookup**: минимальная установка. Использовать `python3 -c "import socket; print(socket.getaddrinfo('domain.com',80)[0][4][0])"`
- **amnezia-dns**: был на 172.29.172.254, удалён
- **Порт 3000**: AdGuard web UI — свободен

## 204.77.1.107 (parafin.duckdns.org, США)
- **OS**: Ubuntu 24.04
- **VPN stack**: sing-box, Docker Amnezia (awg/wireguard/xray), wg-easy (175MB image), hysteria, mita
- **systemd-resolved**: НЕ активен (inactive), порт 53 свободен
- **openclaw-gateway**: занимает порт 5353 (mDNS), но это не мешает unbound на том же порту — unbound слушает 127.0.0.1:5353, openclaw на 0.0.0.0:5353. openclaw потреблял 378MB RAM.
- **amnezia-dns**: существовал, НЕ мапил порт 53 на хост (`docker port` пустой). Удалён при настройке AdGuard.
- **Playwright**: был установлен (647MB Chromium, 2 браузера + ffmpeg) — не использовался ни одним процессом. Тестовые скрипты (test_playwright2.js, test_playwright4.js) от 2 июля. Удалён полностью (cache + npm packages + scripts).
- **fail2ban logrotate**: падает при загрузке — fail2ban.sock не готов. Косметика.
- **Загрузка диска**: 79% после чистки (было 88%). Основные потребители: openclaw (1.1GB) + Docker (1.1GB, 5 images: amnezia-xray, amnezia-awg, amnezia-wireguard, wg-easy, watchtower) + npm (163MB)
- **Старые ядра**: было 3 (6.8.0-134 + 6.8.0-136 + meta). Старое purge'нуто.
- **Запросы Netflix/Google/GTM из-под VPN**: не блокировать — могут ломать функциональность.
- **Rewrite rules** (applied 2026-07-20, 15 правил — блокировка корпоративных DNS-leaks через VPN):
  - `ms-sccmmsk001.bee.vimpelcom.ru` → 0.0.0.0 (SCCM client)
  - `yd-kscws001.bee.vimpelcom.ru`, `yd-kscws001.vimpelcom.ru` → 0.0.0.0 (KSC)
  - `yd-kesgtw001.bee.vimpelcom.ru` → 0.0.0.0 (KES gateway)
  - `yd-epomwg001.bee.vimpelcom.ru`, `yd-epomwg001.vimpelcom.ru` → 0.0.0.0 (EPOM)
  - `isaweb.vimpelcom.ru` → 0.0.0.0 (ISA Server)
  - `wpad.bee.vimpelcom.ru`, `wpad.vimpelcom.ru` → 0.0.0.0 (WPAD)
  - `bee.vimpelcom.ru`, `vimpelcom.ru` → 0.0.0.0 (зоны целиком)
  - `_lyra-mdns._udp.local`, `local` → 0.0.0.0 (mDNS leaks)
  - `report.appmetrica.yandex.net`, `mc.yandex.ru` → 0.0.0.0 (Яндекс.Метрика)
  - YAML backup saved at `/root/adguard-rewrite-rules-backup.yaml`

## 46.30.47.120 — rewrites (актуальный список на момент настройки)
- 16 rewrite-правил: vimpelcom.ru (зона), bee.vimpelcom.ru (зона), 9 конкретных доменов (SCCM, Kaspersky, ISA, WPAD, AD), _lyra-mdns._udp.local, local, report.appmetrica.yandex.net, mc.yandex.ru, api.browser.yandex.net
- Все → 0.0.0.0
- Эффект: ~85% шума убрано (с 5000+ до ~1000 запросов/сутки)
