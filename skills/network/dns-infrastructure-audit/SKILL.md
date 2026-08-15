---
name: dns-infrastructure-audit
version: 1.0.0
description: "Use when Audit and provision DNS infrastructure on"
critic_status: done
---

# DNS Infrastructure Audit

Inspect and verify DNS resolution chain on a Linux VPS — from client through VPN/proxy, local resolver (AdGuard Home / Pi-hole), to upstream.

## When to Use

- Проверить, как настроен AdGuard Home на VPS: работает ли, какой upstream, фильтры
- Проверить связку VPN + DNS: как трафик клиентов попадает в локальный резолвер
- Диагностировать, почему не работает фильтрация или разрешение имён
- Сравнить DNS-стек на нескольких серверах
- Убедиться, что DNS не торчит наружу без ограничений

## Audit Checklist

### 1. Service Status

```bash
systemctl status AdGuardHome --no-pager
```

Проверить:
- `Active: active (running)` или inactive/dead
- `Loaded: loaded/enabled` или not-found (нет systemd-юнита)
- Командная строка запуска (какие порты, рабочая директория)

Без systemd — проверить docker:
```bash
docker ps --format '{{.Names}} {{.Image}} {{.Status}} {{.Ports}}' | grep -i dns
```

### 2. Listening Ports

```bash
ss -tlnp | grep -E ':53 |:3000|:80 |:853|:443'
```

Что искать:
- `53` — plain DNS (AdGuardHome, amnezia-dns, systemd-resolved)
- `3000` — AdGuard web UI (или `80`, если настроен reverse proxy)
- `853` — DNS-over-TLS
- `443` / `80` — DoH (если TLS настроен)

### 3. AdGuardHome Config

```bash
cat /opt/AdGuardHome/AdGuardHome.yaml
```

Ключевые поля:
- `dns.bind_hosts` / `dns.port` — на чём слушает DNS
- `dns.upstream_dns` — upstream-серверы (DoH/DoT/UDP)
- `dns.bootstrap_dns` — bootstrap для DoH
- `dns.upstream_mode` — load_balance / parallel / fastest
- `dns.fallback_dns` — если пусто, нет резерва
- `dns.enable_dnssec` — хорошо если true
- `dns.refuse_any` — true блокирует DNS-амплификацию
- `dns.allowed_clients` — если пусто, DNS открыт всем
- `dns.ratelimit` — ограничение запросов/сек
- `http.address` — где висит web UI
- `filters` — какие блок-листы включены
- `tls.enabled` — если false, DoH/DoT выключены
- `filtering.protection_enabled` — общий тумблер фильтрации

Проверить наличие бинарника:
```bash
ls -la /opt/AdGuardHome/AdGuardHome
```

### 4. System DNS Resolution Chain

```bash
cat /etc/resolv.conf
```

- `nameserver 127.0.0.1` — локальный резолвер (AdGuard / systemd-resolved)
- Если несколько — fallback порядок

### 5. iptables DNS Redirect

```bash
iptables -t nat -L PREROUTING -n -v
iptables -t nat -L OUTPUT -n -v
```

Искать REDIRECT на порт 53:
```
REDIRECT   udp  --  wg0  *  0.0.0.0/0  0.0.0.0/0  udp dpt:53 redir ports 53
REDIRECT   udp  --  *    *  172.x.x.x  0.0.0.0/0  udp dpt:53 redir ports 53
```

Что это значит:
- Трафик с VPN-интерфейса (wg0) или docker-сети принудительно идёт в локальный DNS
- Без этого правила клиенты используют свой upstream (обычно 8.8.8.8), минуя AdGuard

### 6. Docker DNS Integration

```bash
docker ps -a --format '{{.Names}} {{.Image}} {{.Status}} {{.Ports}}'
```

Искать:
- `amnezia-dns` — контейнер на порту 53 (альтернатива AdGuard)
- `amnezia-*` — весь Amnezia VPN stack (xray, shadowsocks, awg, wireguard)

### 7. sing-box DNS Chain

Если используется sing-box (актуально для прокси/VPN):
```bash
find /etc/s-box -name '*.json' -exec echo '--- {} ---' \; -exec cat {} \;
```

Проверить секцию `dns` в конфиге:
- Какие серверы (DoH/UDP)
- Есть ли fakeip (198.18.0.0/15) — для TUN-режима
- Есть ли hijack-dns — перехват DNS на порту 53
- Финал (final) — какой upstream используется по умолчанию

### 8. Web UI Security

Проверить, не висит ли AdGuard web UI на 0.0.0.0 без TLS:
- `http.address: 0.0.0.0:3000` — доступен снаружи, пароль в открытом виде
- `http.address: 127.0.0.1:3000` — локально, безопасно
- `tls.enabled: false` — нет HTTPS/DoH/DoT

## Common Patterns

### Pattern A: AdGuardHome systemd → iptables redirect

```
Client → (VPN/WireGuard) → iptables REDIRECT port 53 → AdGuardHome (:53) → Quad9 DoH
```

Проверка:
1. systemd — `systemctl status AdGuardHome`
2. iptables — `iptables -t nat -L PREROUTING`
3. resolv.conf — `nameserver 127.0.0.1`
4. upstream — DoH в конфиге AdGuard

### Pattern B: Amnezia DNS docker container

```
Client → Amnezia VPN → amnezia-dns container (:53) → upstream
```

Характерно для AmneziaVPN. AdGuardHome часто не запущен — конфиг лежит мёртвым.

### Pattern C: sing-box TUN + DNS chain

```
Client → sing-box TUN → hijack-dns → fakeip/aliDns/GoogleDNS
```

Встроенная DNS-цепочка sing-box. AdGuardHome может работать параллельно для локального трафика.

## Provisioning / Setup

Set up AdGuardHome on a VPS running sing-box VPN, with full DNS chain integration. Процесс от начала до конца.

### Step 1: Check Prerequisites

```bash
# Already have AdGuardHome binary + config?
ls -la /opt/AdGuardHome/

# What's on port 53?
ss -tlnp | grep ':53 '

# Is there a DNS docker container?
docker ps --format '{{.Names}} {{.Image}} {{.Status}} {{.Ports}}' | grep dns

# What's the current VPN stack?
systemctl status sing-box --no-pager | head -5
find /etc/s-box -name '*.json' 2>/dev/null
docker ps --format '{{.Names}} {{.Image}} {{.Ports}}'
cat /etc/resolv.conf
```

### Step 2: Free Port 53 (if occupied)

If amnezia-dns or unbound docker container is on port 53:

```bash
docker stop amnezia-dns && docker rm amnezia-dns
```

This container serves Amnezia VPN clients. AdGuardHome will replace it.

### Step 3: Create systemd Service

Create `/etc/systemd/system/AdGuardHome.service`:

```
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

Флаги:
- `-p 3000` — web admin порт
- `-l 53` — DNS порт
- `-w /opt/AdGuardHome` — рабочая директория

```bash
systemctl daemon-reload
systemctl enable AdGuardHome
systemctl start AdGuardHome
systemctl status AdGuardHome --no-pager | head -12
```

### Step 4: Point resolv.conf to AdGuard

```bash
cat > /etc/resolv.conf << 'EOF'
nameserver 127.0.0.1
nameserver 1.1.1.1
EOF
```

Первым — локальный AdGuard (проверяет фильтры), запасной — 1.1.1.1.

### Step 5: Set Up iptables DNS Redirect

Принудительно направляем DNS-трафик с VPN-интерфейсов в AdGuard:

```bash
# Docker bridge networks → localhost:53
iptables -t nat -A PREROUTING -s 172.29.172.0/24 -p udp --dport 53 -j REDIRECT --to-ports 53
iptables -t nat -A PREROUTING -s 172.17.0.0/16 -p udp --dport 53 -j REDIRECT --to-ports 53

# WireGuard interface → localhost:53
iptables -t nat -A PREROUTING -i wg0 -p udp --dport 53 -j REDIRECT --to-ports 53
```

Проверить:
```bash
iptables -t nat -L PREROUTING -n -v
```

Важно: эти правила не сохраняются после перезагрузки. Для персистентности — `iptables-persistent` или скрипт в `/etc/rc.local`.

### Step 6: Refresh AdGuard Filters

AdGuard скачивает фильтры при старте асинхронно. Если rules_count=0 — форсировать через API:

```bash
# Получить куки (пароль из AdGuardHome.yaml)
curl -s -X POST http://127.0.0.1:3000/control/login \
  -H 'Content-Type: application/json' \
  -d '{"name":"admin","password":"<PASSWORD>"}' \
  -c /tmp/ag-cookies.txt

# Обновить фильтры
curl -s -X POST http://127.0.0.1:3000/control/filtering/refresh \
  -H 'Content-Type: application/json' -d '{}' \
  -b /tmp/ag-cookies.txt

# Проверить статус
curl -s http://127.0.0.1:3000/control/filtering/status \
  -b /tmp/ag-cookies.txt | python3 -m json.tool
```

Ожидаемый результат: `rules_count > 100000`, `last_updated` не пустое.

### Step 7: Configure sing-box DNS Chain (sbox.json)

В sbox.json (клиентская конфигурация для TUN-режима) добавить adguard как первый DNS-сервер и поменять final:

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

Итоговая цепочка DNS:
1. `adguard` (UDP 127.0.0.1:53) — **final**, первый сервер
2. `aliDns` (DoH Alibaba) — для geosite-cn (Китай)
3. `local` (UDP 223.5.5.5) — для Direct mode
4. `proxyDns` (Google DoH через proxy) — для Global mode
5. `fakeip` (198.18.0.0/15) — для TUN-маршрутизации

`final: adguard` означает, что все DNS-запросы, не попавшие под правила, идут в AdGuard. Исключения:
- geosite-cn → aliDns (китайские сайты напрямую, быстрее)
- Direct mode → local (прямой резолв)
- Global mode → proxyDns (через прокси, для конспирации)

### Step 8: Verify Blocking

```bash
# Обычный домен — должен резолвиться
dig @127.0.0.1 google.com +short

# Рекламный домен — должен вернуть 0.0.0.0
dig @127.0.0.1 doubleclick.net +short
dig @127.0.0.1 ad.doubleclick.net +short
```

### Step 9: Check sing-box Still Running

```bash
systemctl is-active sing-box
```

Перезагрузка sing-box не требуется — sbox.json читается при старте клиентского процесса.

## Anti-Patterns

- **AdGuardHome установлен, но не запущен** — конфиг есть, systemd-юнита нет. Процесс мёртв.
- **AdGuardHome на 0.0.0.0:80/3000 без TLS** — пароль передаётся открытым текстом.
- **allowed_clients пустой** — любой может использовать как открытый резолвер.
- **Один upstream без fallback** — при падении Quad9/Cloudflare всё встанет.
- **Два слоя DNS без координации** — sing-box делает свой DNS, AdGuard свой, между собой не пересекаются.
- **VPN-клиенты не попадают в AdGuard** — нет iptables-правила на интерфейс VPN (udp dpt:53 → redir ports 53).

## Provisioning Patterns

### Pattern D: AdGuard Home + sing-box DNS chain

```
VPN client TUN → sing-box → AdGuardHome (:53) → Quad9 DoH
```

Характерно: AdGuardHome как systemd-сервис, sbox.json с final=adguard, iptables redirect для wg0/docker.

### Pattern E: Full replacement of amnezia-dns

```
Before: amnezia-dns (unbound docker) → upstream
After:  AdGuardHome (systemd, port 53) → Quad9 DoH
        + sbox.json final=adguard
        + iptables redirect from docker/WireGuard
```

## Pitfalls

- `systemctl cat AdGuardHome` возвращает "not found" — значит сервис не зарегистрирован, не systemctl status, а именно cat.
- Если на порту 53 сидит amnezia-dns (docker), AdGuardHome стартовать не сможет — порт занят.
- sing-box может иметь `sniff_override_destination: true` — переопределение DNS на уровне прокси, что делает локальный DNS бесполезным для клиентов этого прокси.
- iptables правила могут не сохраняться после перезагрузки (нужен iptables-persistent или аналог).
