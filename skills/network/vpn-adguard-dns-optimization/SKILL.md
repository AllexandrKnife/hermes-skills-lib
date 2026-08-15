---
name: vpn-adguard-dns-optimization
version: 1.0.0
description: "Use when >-"
critic_status: done
  Настройка связки VPN + AdGuardHome с unbound, parallel upstreams и агрессивными
  фильтрами на VPS. Превращает sing-box/WireGuard/Amnezia в DNS-фильтрующий
  шлюз.
---
## When to Use

Use when >-.


# VPN + AdGuardHome DNS Optimization

## Схема

```
клиент → VPN (sing-box/WG/Amnezia)
         → iptables redirect DNS (порт 53)
         → AdGuardHome (фильтрация, 64MB кеш)
            ├── unbound (127.0.0.1:5353, рекурсия, UDP)
            ├── Quad9 DoH (parallel)
            ├── Cloudflare DoH (parallel)
            └── AdGuard DNS DoH (parallel)
```

## Действия

### 1. Установка AdGuardHome

```
cd /opt && curl -fsSL https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_amd64.tar.gz -o /tmp/agh.tar.gz && tar -xzf /tmp/agh.tar.gz -C /opt/
mkdir -p /opt/AdGuardHome/data
```

### 2. Создать config

Базовый `/opt/AdGuardHome/AdGuardHome.yaml`:
- http.address: 0.0.0.0:3000
- users: [{name: admin, password: <bcrypt>}]
- dns.port: 53, bind_hosts: [0.0.0.0]
- upstream_dns: [https://dns10.quad9.net/dns-query]
- filters: AdGuard DNS filter (id:1, enabled:true)
- dnssec: true, refuse_any: true

### 3. Systemd-сервис

```
ExecStart=/opt/AdGuardHome/AdGuardHome -w /opt/AdGuardHome -p 3000 -s run -l 53
Restart=always, RestartSec=10
systemctl daemon-reload && systemctl enable --now AdGuardHome
```

### 4. Остановить amnezia-dns (если есть)
`docker stop amnezia-dns && docker rm amnezia-dns`

### 5. resolv.conf
```
nameserver 127.0.0.1
nameserver 1.1.1.1
```

### 6. Iptables redirect
```
iptables -t nat -A PREROUTING -s 172.29.172.0/24 -p udp --dport 53 -j REDIRECT --to-ports 53
iptables -t nat -A PREROUTING -s 172.17.0.0/16 -p udp --dport 53 -j REDIRECT --to-ports 53
iptables -t nat -A PREROUTING -i wg0 -p udp --dport 53 -j REDIRECT --to-ports 53
iptables -t nat -A PREROUTING -d 172.29.172.254 -p udp --dport 53 -j REDIRECT --to-ports 53
```

### 7. sbox.json DNS chain
```
cfg['dns']['servers'].insert(0, {'tag':'adguard','type':'udp','server':'127.0.0.1','server_port':53})
cfg['dns']['final'] = 'adguard'
```

### 8. Установка unbound
```
apt-get install -y unbound python3-yaml
```

/etc/unbound/unbound.conf.d/aggressive.conf:
- interface: 127.0.0.1, port: 5353
- cache-min-ttl: 3600, cache-max-ttl: 86400
- msg-cache-size: 128m, rrset-cache-size: 256m
- prefetch: yes, serve-expired: yes
- root-hints: /var/lib/unbound/root.hints

```
wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
chown -R unbound:unbound /var/lib/unbound/
systemctl restart unbound
```

Важно: НЕ дублировать auto-trust-anchor-file.

### 9. Parallel upstreams + кеш 64MB
```
curl -X POST http://127.0.0.1:3000/control/dns_config \
  -d '{"upstream_dns":["127.0.0.1:5353","https://dns10.quad9.net/dns-query","https://dns.cloudflare.com/dns-query","https://dns.adguard-dns.com/dns-query"],"upstream_mode":"parallel","cache_size":67108864}'
```

### 10. Добавить фильтры
```
curl -X POST http://127.0.0.1:3000/control/filtering/add_url \
  -d '{"url":"https://big.oisd.nl/","name":"OISD","enabled":true}'
curl -X POST http://127.0.0.1:3000/control/filtering/add_url \
  -d '{"url":"https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/multi.txt","name":"HaGeZi Multi","enabled":true}'
```
Итог: ~916k правил.

### 11. Персистентность в YAML
Сохранить runtime-конфиг в YAML через python3-yaml.

### 12. DNS rewrites (опционально)
```
curl -X POST http://127.0.0.1:3000/control/rewrite/add \
  -d '{"domain":"local","answer":"0.0.0.0"}'
curl -X POST http://127.0.0.1:3000/control/rewrite/add \
  -d '{"domain":"_lyra-mdns._udp.local","answer":"0.0.0.0"}'
```

## Проверка
- dig @127.0.0.1 google.com +short → IP
- dig @127.0.0.1 doubleclick.net +short → 0.0.0.0
- systemctl is-active AdGuardHome unbound → active

## Pitfalls
- systemd-resolved на порту 53: отключить stub-listener
- unbound auto-trust-anchor-file: не дублировать
- iptables правила слетают при перезагрузке — нужен iptables-persistent
