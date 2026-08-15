---
name: adguard-vpn-dns
version: 1.0.0
description: "Use when >"
critic_status: done
  Установка и настройка AdGuardHome на VPS, интеграция с sing-box/Amnezia VPN,
  оптимизация DNS через unbound + parallel upstreams.
trigger: >
  Пользователь просит настроить AdGuardHome, DNS-фильтрацию на VPN-сервере,
  оптимизировать DNS-цепочку, или проверить/почистить AdGuard.
---
## When to Use

Use when >.


# AdGuardHome + VPN + DNS

## Общая схема

```
VPN-клиент → sing-box/WG/Amnezia → iptables redirect :53 → AdGuardHome
                                                              ├── unbound (127.0.0.1:5353, UDP, рекурсия)
                                                              ├── Quad9 DoH
                                                              ├── Cloudflare DoH
                                                              └── AdGuard DNS DoH
                                                              └── upstream_mode: parallel
```

## Шаги установки

### 1. Установка AdGuardHome

```bash
cd /opt
curl -fsSL https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_amd64.tar.gz -o /tmp/agh.tar.gz
tar -xzf /tmp/agh.tar.gz -C /opt/
```

### 2. Файл конфигурации

Создать `/opt/AdGuardHome/AdGuardHome.yaml`:

```yaml
http:
  address: 0.0.0.0:3000
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  upstream_dns:
    - 127.0.0.1:5353
    - https://dns10.quad9.net/dns-query
    - https://dns.cloudflare.com/dns-query
    - https://dns.adguard-dns.com/dns-query
  upstream_mode: parallel
  bootstrap_dns:
    - 9.9.9.10
    - 149.112.112.10
    - 1.1.1.1
  cache_size: 67108864
  cache_ttl_min: 300
  cache_ttl_max: 86400
  enable_dnssec: true
  refuse_any: true
users:
  - name: admin
    password: $2a$10$...
filters:
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: true
    url: https://big.oisd.nl/
    name: OISD
    id: 100
  - enabled: true
    url: https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/multi.txt
    name: HaGeZi Multi
    id: 101
schema_version: 34
```

Пароль — bcrypt-хэш. При первом запуске AdGuardHome создаст sessions.db сам.

### 3. Systemd-сервис

`/etc/systemd/system/AdGuardHome.service`:

```ini
[Unit]
Description=AdGuard Home: Network-level blocker
ConditionFileIsExecutable=/opt/AdGuardHome/AdGuardHome
After=syslog.target network-online.target

[Service]
StartLimitInterval=5
StartLimitBurst=10
ExecStart=/opt/AdGuardHome/AdGuardHome -w /opt/AdGuardHome -p 3000 -s run -l 53
WorkingDirectory=/tmp
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable --now AdGuardHome
```

### 4. Освобождение порта 53

Перед запуском AdGuardHome проверить, кто занимает порт 53:

```bash
ss -tlnp | grep ':53 '
```

**systemd-resolved** (Ubuntu): отключить stub-listener:

```bash
sed -i 's/^#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
echo 'DNSStubListener=no' >> /etc/systemd/resolved.conf
systemctl restart systemd-resolved
```

**amnezia-dns** (Docker): остановить и удалить контейнер:

```bash
docker stop amnezia-dns && docker rm amnezia-dns
```

### 5. /etc/resolv.conf

```bash
cat > /etc/resolv.conf << 'EOF'
nameserver 127.0.0.1
nameserver 1.1.1.1
EOF
```

## Интеграция с VPN

### sing-box (sbox.json — клиентская конфигурация)

Добавить `adguard` как первый DNS-сервер и установить `final: adguard`:

```python
import json
with open('/etc/s-box/sbox.json', 'r') as f:
    cfg = json.load(f)
cfg['dns']['servers'].insert(0, {
    'tag': 'adguard',
    'type': 'udp',
    'server': '127.0.0.1',
    'server_port': 53
})
cfg['dns']['final'] = 'adguard'
with open('/etc/s-box/sbox.json', 'w') as f:
    json.dump(cfg, f, indent=4)
```

### Iptables redirect

Трафик с VPN-интерфейсов и docker-сетей принудительно направляется в AdGuard:

```bash
iptables -t nat -A PREROUTING -i wg0 -p udp --dport 53 -j REDIRECT --to-ports 53
iptables -t nat -A PREROUTING -s 172.29.172.0/24 -p udp --dport 53 -j REDIRECT --to-ports 53
iptables -t nat -A PREROUTING -s 172.17.0.0/16 -p udp --dport 53 -j REDIRECT --to-ports 53
iptables -t nat -A PREROUTING -d 172.29.172.254 -p udp --dport 53 -j REDIRECT --to-ports 53
```

Первый — для WireGuard (wg0), второй — для amnezia-dns-net, третий — для docker0, четвёртый — для старого IP amnezia-dns.

## DNS-оптимизация (unbound)

### Установка

```bash
apt-get install -y unbound
```

### Конфигурация

`/etc/unbound/unbound.conf.d/aggressive.conf`:

```
server:
    interface: 127.0.0.1
    port: 5353
    do-ip4: yes
    do-ip6: yes
    do-udp: yes
    do-tcp: yes
    val-log-level: 2
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    msg-cache-size: 128m
    rrset-cache-size: 256m
    prefetch: yes
    prefetch-key: yes
    serve-expired: yes
    serve-expired-ttl: 86400
    num-threads: 2
    so-rcvbuf: 4m
    so-sndbuf: 4m
    infra-cache-numhosts: 10000
    hide-identity: yes
    hide-version: yes
    root-hints: /var/lib/unbound/root.hints
    access-control: 127.0.0.0/8 allow
    aggressive-nsec: yes
    qname-minimisation: yes
```

**ВАЖНО**: не дублировать `auto-trust-anchor-file` — Debian/Ubuntu уже содержит
`root-auto-trust-anchor-file.conf`, повторная директива приведёт к ошибке.

```bash
wget -q -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
chown -R unbound:unbound /var/lib/unbound/
systemctl restart unbound
```

### Проверка

```bash
unbound-checkconf
dig @127.0.0.1 -p 5353 google.com +short
```

## Фильтрация

### Базовые фильтры (92-158k правил)

- AdGuard DNS filter — обязателен
- OISD (`https://big.oisd.nl/`) — ~327k правил
- HaGeZi Multi (`https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/multi.txt`) — ~430k правил
- AdAway — ~6.5k правил (AdGuard-hosted версия)

### Добавление через API

```bash
curl -c /tmp/cookies -X POST http://127.0.0.1:3000/control/login \
  -H 'Content-Type: application/json' \
  -d '{"name":"admin","password":"PASSWORD"}'

curl -b /tmp/cookies -X POST http://127.0.0.1:3000/control/filtering/add_url \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://big.oisd.nl/","name":"OISD","enabled":true}'
```

### Сохранение в YAML

Фильтры, добавленные через API, не попадают в `AdGuardHome.yaml` автоматически.
Их нужно скопировать из `/control/filtering/status` в конфиг для персистентности.

### Тестирование

```bash
dig @127.0.0.1 google.com +short        # должен вернуть IP
dig @127.0.0.1 doubleclick.net +short    # должен вернуть 0.0.0.0
```

## Pitfalls

- **Порт 53 уже занят**: проверить `systemd-resolved` (Ubuntu) и `amnezia-dns` (Docker)
- **AdGuardHome не стартует**: проверить `journalctl -u AdGuardHome`, чаще всего порт занят
- **unbound-checkconf ругается**: почти всегда дублирование `auto-trust-anchor-file`
- **Фильтры не сохраняются после перезапуска**: API не пишет в YAML, скопировать вручную
- **sbox.json — клиентский конфиг**: изменения в нём влияют на клиентов, подключающихся через TUN
- **sb.json — серверный**: не содержит DNS-секции, менять не нужно
- **AdAway filter не включается через API**: эндпоинт `/control/filtering/enable` возвращает 404, `/control/filtering/set_url` возвращает "data is absent". Решение — включить фильтр напрямую в `AdGuardHome.yaml` (поставить `enabled: true`) и перезапустить AdGuardHome
- **Нет dig/nslookup на минимальных системах**: Ubuntu minimal не содержит dnsutils. Установка `bind9-host` не всегда помогает (вывод host обрезается). Надёжный fallback: `python3 -c "import socket; print(socket.getaddrinfo('domain.com',80)[0][4][0])"`
- **Playwright/Chromium — мёртвый груз 647MB**: при очистке VPS проверять, используются ли Playwright-браузеры реально (нет процессов chrome/chromium, тестовые скрипты старые). Если нет — `rm -rf /root/.cache/ms-playwright`
- **Разные версии Ubuntu — разное поведение systemd-resolved**:
  - 22.04: активен, слушает 127.0.0.53:53, иногда блокирует TCP 0.0.0.0:53 (87.121.38.60)
  - 24.04: может быть неактивен, порт 53 свободен (204.77.1.107)
  - Debian 12: активен, слушает 127.0.0.53:53, не блокирует 0.0.0.0:53 (46.30.47.120)
- **amnezia-dns не всегда мапит порт на хост**: docker port может быть пустым, но контейнер может блокировать порт 53 в docker-сети

## VPS health check (перед/после настройки)

Хорошая практика — проверить и почистить VPS при первом входе:

```bash
# Диск
df -h
du -sh /opt/* /var/log /tmp /root /var/cache/apt 2>/dev/null | sort -rh | head -15

# Память
free -h

# Журналы
journalctl --disk-usage
journalctl --vacuum-time=7d

# APT
apt-get clean
apt-get autoremove -y

# Ядра (оставить только текущее + meta)
dpkg -l 'linux-image-*' 2>/dev/null | grep ^ii
apt-get purge -y linux-image-OLD

# Docker
docker image prune -a -f
docker system df

# Playwright/Chromium — проверить, используется ли
ps aux | grep -i 'chrome\|chromium' | grep -v grep
ls -la /root/.cache/ms-playwright/   # если нет процессов — rm -rf
```

## Типовая производительность

После настройки (unbound + parallel):

| Сценарий | Холодный кеш | Горячий кеш |
|----------|:-----------:|:----------:|
| Quad9 рядом (EU) | 5-15ms | 0-3ms |
| Quad9 далеко | 9-25ms → **6-8ms** | 0ms |
| unbound рекурсия | 7-48ms | **0ms** |
| Блокировка (0.0.0.0) | 0-4ms | 0ms |

Блок-рейт после добавления OISD + HaGeZi: ~10-18% (зависит от трафика).

## Query log analysis & DNS leak mitigation

Корпоративные сети (AD, SCCM, Kaspersky) и устройства (Roku, smart TV) генерируют
DNS-запросы к внутренним зонам, которые через VPN уходят к публичным upstream'ам.
AdGuard возвращает NXDOMAIN, но клиенты продолжают долбить — сотни запросов/час.

### Анализ лога

```bash
# Авторизация
curl -c /tmp/cookies -X POST http://127.0.0.1:3000/control/login \
  -H 'Content-Type: application/json' \
  -d '{"name":"admin","password":"PASSWORD"}'

# Поиск по домену
curl -b /tmp/cookies "http://127.0.0.1:3000/control/querylog?search=corpdomain&limit=200"

# Топ запросов за последние 1000
curl -b /tmp/cookies "http://127.0.0.1:3000/control/querylog?limit=1000" | python3 -c "
import sys,json
from collections import defaultdict
d=json.load(sys.stdin)
domains = defaultdict(int)
for e in d.get('data',[]):
    q = e.get('question',{})
    name = q.get('name','?') if q else '?'
    if name != '?': domains[name] += 1
for name,cnt in sorted(domains.items(), key=lambda x:-x[1])[:30]:
    print('%4d x %s' % (cnt, name))
"
```

### Типовые внутренние зоны (NXDOMAIN в публичном DNS)

| Домен/паттерн | Что генерирует | Источник |
|---------------|---------------|----------|
| `wpad.*.corp.ru` | WPAD (Web Proxy Auto-Discovery) | WinHTTP, браузеры, .NET |
| `_ldap._tcp.dc._msdcs.*` | Active Directory DC discovery | NetLogon (lsass) |
| `_kerberos._tcp.dc._msdcs.*` | Kerberos auth | Windows Logon |
| `ms-sccm*.corp.ru` | System Center client | CCMExec |
| `yd-kscws*.corp.ru` | Kaspersky Security Center | KES Agent (avp.exe) |
| `yd-kesgtw*.corp.ru` | Kaspersky Endpoint Security gateway | KES Agent |
| `yd-epomwg*.corp.ru` | Kaspersky EPOM gateway | KES Agent |
| `yd-ormscom*.corp.ru` | System Center Operations Manager | SCOM Agent |
| `isaweb.corp.ru` | Microsoft ISA Server | WinHTTP/Group Policy |
| `_lyra-mdns._udp.local` | Roku Lyra (media discovery) | Roku app/Plex |
| `*._tcp.local` / `*._udp.local` | mDNS leaks (любые сервисы) | Приложения, Windows |

### Блокировка через rewrites

Вместо того чтобы пускать NXDOMAIN-запросы к upstream, добавить rewrite на 0.0.0.0.
AdGuard отвечает мгновенно (0ms), upstream не дёргается.

```bash
# Целая зона (catch-all для subdomain.corp.ru)
curl -b /tmp/cookies -X POST http://127.0.0.1:3000/control/rewrite/add \
  -H 'Content-Type: application/json' \
  -d '{"domain":"corp.ru","answer":"0.0.0.0"}'

# Конкретный домен
curl -b /tmp/cookies -X POST http://127.0.0.1:3000/control/rewrite/add \
  -H 'Content-Type: application/json' \
  -d '{"domain":"ms-sccmmsk001.bee.corp.ru","answer":"0.0.0.0"}'

# mDNS leaks
curl -b /tmp/cookies -X POST http://127.0.0.1:3000/control/rewrite/add \
  -H 'Content-Type: application/json' \
  -d '{"domain":"_lyra-mdns._udp.local","answer":"0.0.0.0"}'
curl -b /tmp/cookies -X POST http://127.0.0.1:3000/control/rewrite/add \
  -H 'Content-Type: application/json' \
  -d '{"domain":"local","answer":"0.0.0.0"}'

# Трекинг/телеметрия
curl -b /tmp/cookies -X POST http://127.0.0.1:3000/control/rewrite/add \
  -H 'Content-Type: application/json' \
  -d '{"domain":"report.appmetrica.yandex.net","answer":"0.0.0.0"}'
curl -b /tmp/cookies -X POST http://127.0.0.1:3000/control/rewrite/add \
  -H 'Content-Type: application/json' \
  -d '{"domain":"mc.yandex.ru","answer":"0.0.0.0"}'
```

**Когда блокировать, а когда нет:**
- `www.googletagmanager.com` (GTM) — не блокировать сразу: ломает формы/виджеты на многих сайтах
- `nrdp*.logs.netflix.com` — не блокировать: Netflix может работать нестабильно
- `clients2.google.com` — не блокировать: Chrome/Google-сервисы
- `api.browser.yandex.net` — блокировать: только синхронизация Яндекс.Браузера

### Персистентность rewrites

Rewrites, добавленные через API, не сохраняются в YAML автоматически.
Скопировать в `AdGuardHome.yaml`:

```python
import yaml, json
with open('/opt/AdGuardHome/AdGuardHome.yaml') as f:
    cfg = yaml.safe_load(f)
# Получить текущие rewrites из API
import urllib.request
req = urllib.request.Request('http://127.0.0.1:3000/control/rewrite/list')
# требуется cookie
cfg['filtering']['rewrites'] = json.loads(urllib.request.urlopen(req).read())
with open('/opt/AdGuardHome/AdGuardHome.yaml', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False)
```

### Проверка эффекта

```bash
# Статистика AdGuard
curl -b /tmp/cookies http://127.0.0.1:3000/control/stats | python3 -c "
import sys,json
d=json.load(sys.stdin)
t=int(d['num_dns_queries']); b=int(d['num_blocked_filtering'])
print('Total: %d, Blocked: %d (%.1f%%)' % (t, b, b/max(t,1)*100))
print('Avg: %s ms' % str(d['avg_processing_time'])[:6])
"

# Список rewrites
curl -b /tmp/cookies http://127.0.0.1:3000/control/rewrite/list
```

**Cтатистика в stats API не содержит `num_replaced_rewrites`** — количество
срабатываний rewrite-правил не показывается, только общее `num_blocked_filtering`.

## Связанные навыки

- `homelab-network-setup` — общее планирование сети
- `homelab-wireguard-vpn` — настройка WireGuard
- `native-mcp` — MCP-клиент для AdGuard API
- `dns-infrastructure-audit` — аудит DNS-инфраструктуры (пересекается)
- `vps-adguard-dns-integration` — почти идентичный навык (см. замечание ниже)

**Замечание**: навыки `adguard-vpn-dns`, `vps-adguard-dns-integration` и `dns-infrastructure-audit` покрывают пересекающуюся область. Фактически это один класс задач (установка/интеграция AdGuardHome + VPN на VPS). Рекомендуется консолидация в один навык с вариантами использования (установка с нуля vs аудит существующего).

## Связанные файлы

- `references/vps-quirks.md` — per-VPS особенности, встреченные при настройке (разные OS, версии systemd-resolved, специфика провайдеров)
