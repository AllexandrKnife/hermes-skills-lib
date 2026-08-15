# VPS DNS Audit Examples

Результаты аудита DNS-инфраструктуры на двух VPS (июль 2026).

## VPS 46.30.47.120 — AdGuard Home мёртв, DNS на Amnezia

### Состояние
- **AdGuardHome**: установлен (`/opt/AdGuardHome/AdGuardHome`, 36MB), конфиг есть (`AdGuardHome.yaml`), НО:
  - systemd-юнита нет
  - Процесс не запущен
  - Порты 53 и 80/3000 не слушаются
- **DNS на порту 53**: `amnezia-dns` (docker-контейнер)
- **AmneziaVPN stack**: xray, shadowsocks, amnezia-dns, amnezia-awg, watchtower
- **Остальное**: Webmin (:10000), sing-box (порты 2086, 48469, 64994), mita (11000-11005)

### Конфиг AdGuard (мёртвый)
```
upstream_dns: [https://dns10.quad9.net/dns-query]
dns.port: 53
http.address: 0.0.0.0:80
tls.enabled: false
filter: AdGuard DNS filter (только filter_1)
```

### Вывод
AdGuardHome настроен, но не используется. DNS разруливает Amnezia. Конфиг лежит мёртвым грузом — чтобы запустить, нужно освободить порт 53 от amnezia-dns.

---

## VPS 45.134.15.185 — AdGuard Home + sing-box VPN (рабочая связка)

### Состояние
- **AdGuardHome**: systemd-сервис (enabled, active)
- **Запуск**: `/opt/AdGuardHome/AdGuardHome -w /opt/AdGuardHome -p 3000 -s run -l 53`
- **Порты**: 53 (DNS), 3000 (web admin)
- **Web UI**: 0.0.0.0:3000 (доступен снаружи, без TLS)

### VPN-стек (sing-box)
5 протоколов в одном конфиге (`/etc/s-box/sb.json`):
- VLESS+Reality (:39261) — маскировка apple.com
- VMess+WS (:2082) — маскировка www.bing.com
- Hysteria2 (:10679) — QUIC
- TUICv5 (:34732) — QUIC
- AnyTLS (:22229) — TLS padding

Outbound: WARP через Cloudflare WireGuard (162.159.192.1:2408), SOCKS5 (:40000)

### DNS Integration
- **iptables redirect**: трафик с wg0, docker-сетей (172.29.172.0/24, 172.17.0.0/16) → localhost:53 → AdGuardHome
- **/etc/resolv.conf**: 127.0.0.1 + 1.1.1.1
- **sing-box sbox.json**: собственный DNS (aliDns DoH, Google DoH, fakeip для TUN) — не пересекается с AdGuard

### Hermes Agent
- Gateway: active, 17ч uptime, 301MB RAM
- HTTP API на 127.0.0.1:8642

### Замечания
1. Два независимых слоя DNS (sing-box → aliDns/Google, AdGuard → Quad9)
2. Web UI AdGuard на 0.0.0.0:3000 — незащищён
3. Нет allowed_clients — DNS открыт
4. Amnezia WG + AWG docker-контейнеры поверх sing-box
