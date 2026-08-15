# VPS DNS Provisioning — Session Examples

Реальные конфиги с двух VPS после настройки AdGuardHome + sing-box DNS chain.

## VPS 45.134.15.185 (Frankfurt, firstbyte.club) — эталон

### systemd unit

```
[Unit]
Description=AdGuard Home: Network-level blocker
ConditionFileIsExecutable=/opt/AdGuardHome/AdGuardHome
After=syslog.target network-online.target

[Service]
StartLimitInterval=5
StartLimitBurst=10
ExecStart=/opt/AdGuardHome/AdGuardHome "-w" "/opt/AdGuardHome" "-p" "3000" "-s" "run" "-l" "53"
WorkingDirectory=/tmp
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=10
EnvironmentFile=-/etc/sysconfig/AdGuardHome

[Install]
WantedBy=multi-user.target
```

### AdGuardHome config (dns section)

```yaml
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  ratelimit: 20
  refuse_any: true
  upstream_dns:
    - https://dns10.quad9.net/dns-query
  bootstrap_dns:
    - 9.9.9.10
    - 149.112.112.10
    - 2620:fe::10
    - 2620:fe::fe:10
  upstream_mode: load_balance
  cache_enabled: true
  cache_size: 4194304
  enable_dnssec: true
  filtering_enabled: true
  protection_enabled: true
```

### sbox.json DNS chain (after provisioning)

```json
"dns": {
  "servers": [
    {"tag": "adguard", "type": "udp", "server": "127.0.0.1", "server_port": 53},
    {"tag": "aliDns", "type": "https", "server": "dns.alidns.com", "path": "/dns-query", "domain_resolver": "local"},
    {"tag": "local", "type": "udp", "server": "223.5.5.5"},
    {"tag": "proxyDns", "type": "https", "server": "dns.google", "path": "/dns-query", "domain_resolver": "aliDns", "detour": "proxy"},
    {"tag": "fakeip", "type": "fakeip", "inet4_range": "198.18.0.0/15", "inet6_range": "fc00::/18"}
  ],
  "rules": [
    {"rule_set": "geosite-cn", "clash_mode": "Rule", "server": "aliDns"},
    {"clash_mode": "Direct", "server": "local"},
    {"clash_mode": "Global", "server": "proxyDns"},
    {"query_type": ["A", "AAAA"], "server": "fakeip"}
  ],
  "final": "adguard",
  "strategy": "prefer_ipv4",
  "independent_cache": true
}
```

### iptables rules

```
Chain PREROUTING:
REDIRECT   udp  --  wg0   *   0.0.0.0/0  0.0.0.0/0   udp dpt:53 redir ports 53
REDIRECT   udp  --  *     *   172.29.172.0/24  0.0.0.0/0   udp dpt:53 redir ports 53
REDIRECT   udp  --  *     *   172.17.0.0/16    0.0.0.0/0   udp dpt:53 redir ports 53
```

### resolv.conf

```
nameserver 127.0.0.1
nameserver 1.1.1.1
```

## VPS 46.30.47.120 (Holland, eurodir.ru) — по тому же шаблону

Идентичная конфигурация. Отличия:
- Debian вместо Ubuntu
- sing-box inbounds на других портах (64994, 2086, 28840, 58919, 48469)
- Не было EnvironmentFile= в systemd unit
- amnezia-dns контейнер остановлен и удалён перед запуском AdGuardHome

## Verification commands

```bash
# AdGuard блокирует рекламу
dig @127.0.0.1 doubleclick.net +short   # → 0.0.0.0
dig @127.0.0.1 ad.doubleclick.net +short # → 0.0.0.0

# Обычные домены работают
dig @127.0.0.1 google.com +short         # → 142.250.x.x

# Фильтр загружен
curl -s -X POST http://127.0.0.1:3000/control/login \
  -H 'Content-Type: application/json' \
  -d '{"name":"admin","password":"1qsxdrgb"}' -c /tmp/ag-cookies.txt

curl -s http://127.0.0.1:3000/control/filtering/status \
  -b /tmp/ag-cookies.txt
# → rules_count > 100000, last_updated != null
```

## End-to-end flow

```
VPN Client (phone/desktop via sing-box TUN)
  → sing-box DNS resolution (sbox.json)
    → rules check:
        - geosite-cn? → aliDns (DoH Alibaba, direct)
        - Direct mode? → local (223.5.5.5)
        - Global mode? → proxyDns (Google DoH via proxy)
        - everything else → adguard (127.0.0.1:53)  ← FINAL
  → AdGuardHome (:53 systemd)
    → filter check (158k+ rules)
    → Quad9 DoH upstream
    → response back to client
```
