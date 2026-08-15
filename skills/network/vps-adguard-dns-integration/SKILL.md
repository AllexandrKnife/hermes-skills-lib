---
name: vps-adguard-dns-integration
version: 1.0.0
description: "Use when Deploy AdGuardHome and integrate it as the"
critic_status: done
tags: [adguard, dns, vpn, sing-box, wireguard, amnezia, iptables, systemd, unbound, optimization]
---

# VPS AdGuardHome + VPN DNS Integration

## Trigger

- User asks to set up AdGuardHome on a VPS
- User asks to connect VPN DNS filtering with AdGuardHome
- User has sing-box / Amnezia / WireGuard VPN and wants AdGuard DNS filtering on all clients
- User asks to replicate an existing AdGuardHome+VPN setup to another VPS

## Prerequisites

- SSH + root access to the target VPS
- Password or key for `sshpass` or key-based auth
- Know the current DNS setup (`systemd-resolved`, `amnezia-dns`, `/etc/resolv.conf`)
- Know the VPN stack (sing-box sb.json/sbox.json, WireGuard, Amnezia, docker containers)

## Steps

### 1. Assess Current State

```bash
# Check if AdGuardHome already exists
systemctl status AdGuardHome --no-pager 2>&1
ls -la /opt/AdGuardHome/ 2>/dev/null

# Check current DNS
cat /etc/resolv.conf
ss -tlnp | grep ':53 '
ss -ulnp | grep ':53 '

# Check VPN stack
systemctl status sing-box --no-pager 2>&1 | head -8
docker ps --format '{{.Names}} {{.Status}} {{.Ports}}' 2>&1
find /etc/s-box -name 'sbox.json' -o -name 'sb.json' 2>/dev/null

# Check iptables
iptables -t nat -L PREROUTING -n -v 2>&1

# Check Amnezia network
docker network inspect amnezia-dns-net --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}' 2>&1
```

### 2. Install AdGuardHome (if not present)

```bash
cd /opt
curl -fsSL https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_amd64.tar.gz -o /tmp/agh.tar.gz
tar -xzf /tmp/agh.tar.gz -C /opt/
```

### 3. Create AdGuardHome Config

Write `/opt/AdGuardHome/AdGuardHome.yaml`:

Key settings:
- `http.address: 0.0.0.0:3000` — web UI
- `dns.port: 53` — DNS listener
- `dns.upstream_dns: [https://dns10.quad9.net/dns-query]` — upstream (Quad9 DoH)
- `dns.bootstrap_dns: [9.9.9.10, 149.112.112.10, 2620:fe::10, 2620:fe::fe:10]`
- `dns.enable_dnssec: true`
- `dns.refuse_any: true`
- `filters[0]: {url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt, name: "AdGuard DNS filter", enabled: true}`

Password hash: use existing bcrypt hash from another VPS, or set one via the initial web setup.

Full config template — see `references/adguard-config-template.yaml`.

### 4. Create and Start systemd Service

Create `/etc/systemd/system/AdGuardHome.service`:

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
systemctl daemon-reload && systemctl enable AdGuardHome && systemctl start AdGuardHome
```

### 5. Handle Port 53 Conflicts

**systemd-resolved** (Ubuntu): stub listener binds to 127.0.0.53:53 and can prevent AdGuard from binding to TCP 0.0.0.0:53.

```bash
# Disable stub resolver
echo 'DNSStubListener=no' >> /etc/systemd/resolved.conf
systemctl restart systemd-resolved
```

**amnezia-dns** (docker): container binding to port 53 in docker network.

```bash
docker stop amnezia-dns && docker rm amnezia-dns
```

### 6. Update /etc/resolv.conf

```bash
cat > /etc/resolv.conf << 'EOF'
nameserver 127.0.0.1
nameserver 1.1.1.1
EOF
```

### 7. Update sing-box Client Config (sbox.json)

Add `adguard` as the first DNS server and set it as `final`:

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

Resulting chain: `['adguard', 'aliDns', 'local', 'proxyDns', 'fakeip']` with `final: adguard`.
- `aliDns` kept for geosite-cn (Chinese sites resolve directly)
- `proxyDns` kept for Global clash mode (DNS through proxy)
- `local` kept for Direct mode

### 8. Set Up iptables DNS Redirects

```bash
# Amnezia docker network → redirect to AdGuard
iptables -t nat -A PREROUTING -s 172.29.172.0/24 -p udp --dport 53 -j REDIRECT --to-ports 53

# Docker default bridge
iptables -t nat -A PREROUTING -s 172.17.0.0/16 -p udp --dport 53 -j REDIRECT --to-ports 53

# WireGuard interface
iptables -t nat -A PREROUTING -i wg0 -p udp --dport 53 -j REDIRECT --to-ports 53

# Old amnezia-dns IP (172.29.172.254) — catches legacy client configs
iptables -t nat -A PREROUTING -d 172.29.172.254 -p udp --dport 53 -j REDIRECT --to-ports 53
```

### 9. Refresh AdGuard Filters and Verify

```bash
# Login + refresh
curl -s -X POST http://127.0.0.1:3000/control/login \
  -H 'Content-Type: application/json' \
  -d '{"name":"admin","password":"<password>"}' \
  -c /tmp/agc.txt

curl -s -X POST http://127.0.0.1:3000/control/filtering/refresh \
  -H 'Content-Type: application/json' -d '{}' -b /tmp/agc.txt

# Check filter status
curl -s http://127.0.0.1:3000/control/filtering/status -b /tmp/agc.txt

# Test blocking (use Python since dig/host may not be installed on minimal systems)
python3 -c "
import socket
for domain in ['google.com', 'doubleclick.net']:
    try:
        ip = socket.getaddrinfo(domain, 80)[0][4][0]
        status = 'BLOCKED' if ip.startswith('0.') else 'resolved'
        print(f'{domain}: {ip} ({status})')
    except Exception as e:
        print(f'{domain}: ERROR {e}')
"

# Check stats
curl -s http://127.0.0.1:3000/control/stats -b /tmp/agc.txt
```

**Expected:**
- `google.com` → real IP (resolved)
- `doubleclick.net` → `0.0.0.0` (BLOCKED)
- Stats show queries and blocked count > 0

## Optimization: Local Recursive Resolver (unbound)

For better latency and resilience, add **unbound** as a local recursive resolver on port 5353, then configure AdGuard to use it as the primary upstream in parallel with DoH fallbacks.

### DNS chain after optimization

```
Client → AdGuard (64MB cache, local filtering)
         ├── unbound (127.0.0.1:5353, UDP, recursion from root)
         ├── Quad9 DoH
         ├── Cloudflare DoH
         └── AdGuard DoH
         └── mode: parallel (fastest wins)
```

Cold query: 4-12ms (parallel wins vs ~20ms single DoH before).  
Hot query: 0-4ms (unbound cache <1ms, AdGuard cache).

### Step 1: Install and Configure unbound

```bash
apt-get install -y unbound
```

Create `/etc/unbound/unbound.conf.d/aggressive.conf`:

```yaml
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
    access-control: ::1/128 allow
    aggressive-nsec: yes
    qname-minimisation: yes
```

**IMPORTANT**: Do NOT add `auto-trust-anchor-file` if the system already has
`/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf` — it will cause
"trust anchor presented twice" and unbound won't start.

```bash
# Download root hints
wget -q -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
# Ensure correct ownership
chown -R unbound:unbound /var/lib/unbound/
# Validate and start
unbound-checkconf
systemctl restart unbound
```

Full config template — see `templates/unbound-aggressive.conf`.

### Step 2: Verify unbound Works

```bash
dig @127.0.0.1 -p 5353 google.com +short
```

First query may take 30-150ms (cold recursion from root). Subsequent queries <1ms.

### Step 3: Update AdGuardHome to Use unbound + Parallel Upstreams

Via API (runtime, persists until restart):

```bash
curl -s -X POST http://127.0.0.1:3000/control/login \
  -H 'Content-Type: application/json' \
  -d '{"name":"admin","password":"<password>"}' \
  -c /tmp/ag.txt

curl -s -X POST http://127.0.0.1:3000/control/dns_config \
  -b /tmp/ag.txt \
  -H 'Content-Type: application/json' \
  -d '{
    "upstream_dns": [
      "127.0.0.1:5353",
      "https://dns10.quad9.net/dns-query",
      "https://dns.cloudflare.com/dns-query",
      "https://dns.adguard-dns.com/dns-query"
    ],
    "upstream_mode": "parallel",
    "cache_size": 67108864,
    "bootstrap_dns": ["9.9.9.10","149.112.112.10","1.1.1.1","2620:fe::10"]
  }'
```

Or save to `/opt/AdGuardHome/AdGuardHome.yaml` via Python:

```python
import json, yaml
with open('/opt/AdGuardHome/AdGuardHome.yaml') as f:
    cfg = yaml.safe_load(f)

cfg['dns']['upstream_dns'] = [
    '127.0.0.1:5353',
    'https://dns10.quad9.net/dns-query',
    'https://dns.cloudflare.com/dns-query',
    'https://dns.adguard-dns.com/dns-query'
]
cfg['dns']['upstream_mode'] = 'parallel'
cfg['dns']['cache_size'] = 67108864  # 64 MB
cfg['dns']['bootstrap_dns'] = ['9.9.9.10', '149.112.112.10', '1.1.1.1', '2620:fe::10']

with open('/opt/AdGuardHome/AdGuardHome.yaml', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False)
```

Install `python3-yaml` if missing. Then restart AdGuard:

```bash
systemctl restart AdGuardHome
```

### Step 4: Benchmark Before vs After

```bash
echo "=== UNBOUND COLD ==="
dig @127.0.0.1 -p 5353 $(date +%s%N).test +noall +stats | grep 'Query time'

echo "=== AFTER (parallel) ==="
for d in google.com yandex.ru youtube.com reddit.com; do
  dig @127.0.0.1 $d +noall +stats | grep 'Query time'
done
```

### Why This Works

| Component | Why faster | Trade-off |
|-----------|-----------|-----------|
| unbound (UDP:5353) | No TLS handshake, local recursion, hot cache <1ms | +15-20MB RAM, cold first query 30-150ms |
| parallel mode | All upstreams queried simultaneously, fastest wins | Slightly more bandwidth (4x queries) |
| cache_size: 64MB | 16x more cache entries, TTL up to 24h | +60MB RAM |
| prefetch: yes (unbound) | Refreshes cache before TTL expires | Negligible |

### When Unbound Actually Helps (vs When It Doesn't)

Unbound is **not** a blanket improvement. The gain depends entirely on the
VPS's network distance to widely-deployed DoH anycast networks (Quad9, Cloudflare):

| Scenario | Cold query unbound | Cold query DoH | Winner |
|:---------|:------------------:|:--------------:|:------:|
| VPS near anycast PoP (NL, DE, UK) | 30-150ms (recursion) | 5-15ms (TLS to nearby PoP) | **DoH** |
| VPS far from anycast (RU, Asia, Africa) | 30-150ms (recursion) | 100-400ms (TLS + round-trip) | **Unbound** |
| Hot cache (repeat domains) | <1ms (local RAM) | 3-30ms (anycast) | **Unbound** |
| Failover scenario | Instant (local) | 10s+ (TLS timeout) | **Unbound** |

**Rule of thumb**: `ping -c 3 9.9.9.10`. If latency <15ms, unbound won't improve
cold queries — the benefit is hot cache + resilience. If latency >50ms, unbound
will significantly speed up cold queries too.

See `references/performance-benchmarks.md` for real-world test data on 3 VPSs.

### Parallel Deploy to Multiple VPSs

Use `delegate_task` to apply the same optimization to multiple VPSs in parallel:

```python
# Dispatches subagents that install unbound + update config
# on each VPS simultaneously
```

The subagent approach works well here — each subagent handles one VPS with:
- SSH + apt install unbound
- Write aggressive.conf
- Download root hints + chown
- Update AdGuardHome.yaml with Python yaml
- Restart unbound + AdGuardHome
- Verify resolution

## Troubleshooting

### AdGuardHome exits silently (code 0 or 1) with no log output

**Root cause**: Port 53 already in use (usually systemd-resolved stub, a manually-started AdGuardHome, or another service).

**Check**:
```bash
ss -tlnp | grep ':53 '
ps aux | grep -i adguard | grep -v grep   # catches old AdGuardHome not under systemd
```

**Clue it's a manually-started AdGuardHome**: `systemctl status AdGuardHome` shows
`activating (auto-restart) (Result: exit-code)` with restart counter in the thousands
(4127, 4133, etc.) — systemd keeps restarting because port 53 is held by an
AdGuardHome that was started outside systemd (often with a different command line,
e.g. `-c /opt/AdGuardHome/AdGuardHome.yaml` instead of systemd's `-s run -l 53`).

**Fix**: 
- If **systemd-resolved stub**: add `DNSStubListener=no` to `/etc/systemd/resolved.conf` and restart.
- If **manually-started AdGuardHome** (found via `ps aux`): kill it, then `systemctl start AdGuardHome` — systemd starts clean since port 53 is free.
- If **other service**: stop it, or kill the process and re-verify with `ss -tlnp | grep ':53 '` before starting AdGuardHome.

### sing-box config has duplicate server entries after sed-based edits

**Root cause**: Using sed for JSON manipulation is fragile. Use Python's json module instead.

**Fix**: 
```python
import json
with open('/etc/s-box/sbox.json', 'r') as f:
    cfg = json.load(f)
# Remove all duplicates with same tag
cfg['dns']['servers'] = [s for s in cfg['dns']['servers'] if s['tag'] != 'adguard']
# Insert fresh one
cfg['dns']['servers'].insert(0, {'tag': 'adguard', 'type': 'udp', 'server': '127.0.0.1', 'server_port': 53})
cfg['dns']['final'] = 'adguard'
with open('/etc/s-box/sbox.json', 'w') as f:
    json.dump(cfg, f, indent=4)
```

### dig/host/nslookup not found (minimal Ubuntu)

Use Python's `socket.getaddrinfo()` for DNS testing instead.

## Pitfalls

- **NEVER use sed for JSON manipulation** — the replacement pattern is too greedy. Always use `python3 -c "import json; ..."`.
- **systemd-resolved stub** (127.0.0.53:53) on Ubuntu blocks TCP 0.0.0.0:53 even though `ss` shows it only on 127.0.0.53. Disable `DNSStubListener` before starting AdGuard.
- **amnezia-dns** container holds port 53 even without host port mapping — remove it before starting AdGuard.
- **sbox.json** is the *client* config (for sing-box TUN mode users), **sb.json** is the *server* config (inbounds only). Only sbox.json has a DNS section. Don't confuse them.
- **Broken PPAs block apt-get update**: third-party PPAs with no Release file for the current Ubuntu release cause `apt-get update` to error out. Before installing unbound or any package, check for 404s in `apt-get update` output and remove the offending repo with `add-apt-repository --remove ppa:foo/bar -y` or delete the `.list` file from `/etc/apt/sources.list.d/`.
- **Password hash**: the bcrypt hash in AdGuardHome.yaml must match the password the user later uses to log in to the web UI. The hash is generated once during initial setup. Reuse a known-good hash or run the initial web setup flow.
- **DNS chain order matters**: sing-box evaluates servers in order — `adguard` first means most queries hit local AdGuard. `aliDns` is kept for geosite-cn (Chinese sites resolve faster directly).
- **iptables rules are ephemeral** — they don't survive reboot. For persistence, either save with `iptables-save > /etc/iptables/rules.v4` or add them to a startup script.

## Filter Tuning — Improving Block Rate

After initial setup, the default config uses only one blocklist (AdGuard DNS filter,
~158k rules), which typically yields a block rate of 5-12%. For OSINT work, you
want this higher.

### Check Current Performance

```bash
# Login
curl -s -X POST http://127.0.0.1:3000/control/login \
  -H 'Content-Type: application/json' \
  -d '{"name":"admin","password":"<password>"}' \
  -c /tmp/agc.txt > /dev/null

# Stats
curl -s -b /tmp/agc.txt http://127.0.0.1:3000/control/stats | python3 -c "
import sys,json
d=json.load(sys.stdin)
t=int(d['num_dns_queries'])
b=int(d['num_blocked_filtering'])
print(f'Queries: {t}, Blocked: {b}, Rate: {b/max(t,1)*100:.1f}%')
"

# View top blocked domains (last 200 queries)
curl -s -b /tmp/agc.txt 'http://127.0.0.1:3000/control/querylog?limit=200' | python3 -c "
import sys,json
d=json.load(sys.stdin)
bd={}
for e in d.get('data',[]):
    if e.get('reason') in ('Filtered','Blocked','BlockedBy'):
        dom=e.get('domain','?')
        bd[dom]=bd.get(dom,0)+1
for dom,cnt in sorted(bd.items(),key=lambda x:-x[1])[:15]:
    print(f'  {cnt:>4}x {dom}')
"
```

### Recommended Blocklist Configuration

These lists complement each other — AdGuard catches general ads/trackers, OISD
covers broad threat intelligence, HaGeZi covers specific malware/phishing:

| List | URL | Rules | Notes |
|------|-----|:-----:|-------|
| AdGuard DNS filter | `https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt` | ~158k | Ships enabled by default |
| AdAway Default | `https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt` | ~130k | Android-focused ads, ships disabled |
| OISD | `https://big.oisd.nl/` | ~327k | Broad threat intelligence, curated |
| HaGeZi Multi | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/multi.txt` | ~431k | Aggressive but safe, malware/phishing |

Total with all four enabled: **~1M rules** — typical block rate 15-25%.

### Enabling Filters via API

```bash
# Add OISD
curl -s -b /tmp/agc.txt -X POST http://127.0.0.1:3000/control/filtering/add_url \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://big.oisd.nl/","name":"OISD","enabled":true}'

# Add HaGeZi Multi
curl -s -b /tmp/agc.txt -X POST http://127.0.0.1:3000/control/filtering/add_url \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/multi.txt","name":"HaGeZi Multi","enabled":true}'

# Enable AdAway (if already registered but disabled — use YAML edit for this one)
# The API is finicky with filter id=2, so edit the YAML directly:
python3 -c "
import yaml
with open('/opt/AdGuardHome/AdGuardHome.yaml') as f:
    cfg = yaml.safe_load(f)
for flt in cfg['filters']:
    if 'AdAway' in flt.get('name','') or 'filter_2' in flt.get('url',''):
        flt['enabled'] = True
with open('/opt/AdGuardHome/AdGuardHome.yaml', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False)
"

# Refresh all filters
curl -s -b /tmp/agc.txt -X POST http://127.0.0.1:3000/control/filtering/refresh \
  -H 'Content-Type: application/json' -d '{}'

# Verify
curl -s -b /tmp/agc.txt http://127.0.0.1:3000/control/filtering/status | python3 -c "
import sys,json
d=json.load(sys.stdin)
for f in d['filters']:
    print(f['name'] + ': ' + str(f['rules_count']) + ' enabled=' + str(f['enabled']))
total = sum(f['rules_count'] for f in d['filters'] if f['enabled'])
print(f'TOTAL: {total} rules')
"
```

### Persisting to YAML

After adding filters via API, they may **not** be written to the YAML config file.
If the service restarts, API-added filters are lost. Always save back:

```python
import json, yaml

# Get current runtime config
cfg_runtime = json.loads(open('/tmp/current_filters.json').read())  # from API

# Read YAML
with open('/opt/AdGuardHome/AdGuardHome.yaml') as f:
    cfg = yaml.safe_load(f)

# Merge filter URLs, ensuring enabled=true persists
existing_urls = {f['url'] for f in cfg['filters']}
for rf in cfg_runtime['filters']:
    if rf['url'] not in existing_urls:
        cfg['filters'].append({
            'enabled': rf['enabled'],
            'url': rf['url'],
            'name': rf['name'],
            'id': rf['id']
        })
    else:
        # Update enabled status for existing filters
        for ef in cfg['filters']:
            if ef['url'] == rf['url']:
                ef['enabled'] = rf['enabled']

with open('/opt/AdGuardHome/AdGuardHome.yaml', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False)
```

### Benchmarking Filter Impact

Test with known ad domains:

```bash
for d in \
  doubleclick.net analytics.google.com pagead2.googlesyndication.com \
  adsrvr.org adzerk.net exelator.com scorecardresearch.com \
  outbrain.com taboola.com amazon-adsystem.com criteo.com adnxs.com \
  pubmatic.com openx.net appnexus.com advertising.com adform.com; do
  dig @127.0.0.1 +time=2 +tries=1 $d +short
done | sort | uniq -c
```

Most should resolve to `0.0.0.0`. Domains that resolve to real IPs (like
`scorecardresearch.com`, `pubmatic.com`, `openx.net`) may need custom user rules
or an additional blocklist.

## VPS Health Check + Cleanup

### Standardized Health Check

```bash
echo '=== DISK ==='; df -h /
echo '=== MEMORY ==='; free -h
echo '=== TOP PROCS ==='; ps aux --sort=-%mem | head -10
echo '=== FAILED SERVICES ==='; systemctl --failed --no-pager
echo '=== JOURNAL ==='; journalctl --disk-usage
echo '=== DOCKER ==='; docker system df
echo '=== APT CACHE ==='; du -sh /var/cache/apt/
echo '=== KERNELS ==='; dpkg -l 'linux-image-*' 2>/dev/null | grep ^ii
echo '=== /root BIG DIRS ==='; du -sh /root/* /root/.[!.]* 2>/dev/null | sort -rh | head -10
echo '=== UPTIME ==='; uptime
```

### Routine Cleanup Commands

```bash
# Journal — keep last 7 days
journalctl --vacuum-time=7d

# APT cache
apt-get clean
rm -rf /var/lib/apt/lists/*

# Docker — prune unused images
docker image prune -a -f

# Old rotated logs
rm -f /var/log/*.gz /var/log/*.1 /var/log/*.old

# Old kernels (Ubuntu/Debian)
# Check current: uname -r
# Remove old: apt-get purge -y linux-image-<old-version>-generic

# npm cache (if applicable)
npm cache clean --force

# Remove stale large caches
rm -rf /root/.cache/ms-playwright  # 600MB+ Playwright Chromium — only if not actively scraping with JS
rm -rf /root/.windsurf-server       # 300MB+ IDE cache — remnant from development use
```

### Playwright Bloat — When to Remove It

On OSINT/scraper VPSs, Playwright (`/root/.cache/ms-playwright/`) installs a full
Chromium browser (~650MB) plus headless shell and ffmpeg. Before removing, check:

```bash
# Is any process actually using Chrome/Chromium right now?
ps aux | grep -i 'chrome\|chromium\|playwright'
```

If nothing is running and the scraping pipeline uses `curl_cffi` (Python) or other
TLS-fingerprint bypass tools that don't need JS, the entire Playwright browser
cache is dead weight. Remove it:

```bash
rm -rf /root/.cache/ms-playwright
```

If JS rendering is needed later, install Playwright on-demand for the specific
task rather than keeping it pre-installed offline.

### When 80%+ Disk Is OK

Some VPSs have unavoidable large components:
- Docker images (Amnezia stack ~330MB, wg-easy ~175MB) — essential for operation
- OpenClaw / AI gateways (~1GB) — running service
- Playwright Chromium (~650MB) — only if actively scraping with JS
- Webmin (~150MB) — management panel

Target: keep **free space >15%** of total disk. Below that, actively clean.

## DNS Rewrites for Corporate Internal Domains

When a Windows domain-joined workstation connects through the VPN, it continues
to poll internal corporate resources: Active Directory (LDAP/Kerberos SRV records),
SCCM, Kaspersky Security Center, WPAD, and other internal servers. These domains
**don't exist in public DNS**, so AdGuard returns NXDOMAIN (via upstream). The
result is hundreds of useless DNS queries per hour, all timing out or returning
NXDOMAIN.

### Identify Corporate DNS Leaks

Use the query log to identify internal domain queries:

```bash
curl -s -b /tmp/agc.txt \
  "http://127.0.0.1:3000/control/querylog?limit=500" | python3 -c "
import sys,json
d=json.load(sys.stdin)
domains = {}
for e in d.get('data',[]):
    q = e.get('question',{})
    name = q.get('name','') if q else ''
    dom = '.'.join(name.split('.')[-2:]) if name else ''
    doms[dom] = doms.get(dom,0)+1
for dom,cnt in sorted(domains.items(), key=lambda x:-x[1])[:20]:
    print(f'  {cnt:>4}x {dom}')
"
```

Or search for specific internal domain patterns:

```bash
curl -s -b /tmp/agc.txt \
  "http://127.0.0.1:3000/control/querylog?limit=500&search=vimpelcom" | python3 -c "
import sys,json
d=json.load(sys.stdin)
domains = {}
for e in d.get('data',[]):
    q = e.get('question',{})
    name = q.get('name','') if q else ''
    client = e.get('client','?')
    if name and 'vimpelcom' in name:
        domains[name] = domains.get(name,0)+1
for d,c in sorted(domains.items(), key=lambda x:-x[1])[:20]:
    print(f'  {c:>4}x {d}')
"
```

### Common Corporate DNS Patterns

| Pattern | Service | 
|---------|---------|
| `_ldap._tcp.*._msdcs.<domain>` | **NetLogon** — Domain Controller discovery |
| `_kerberos._tcp.*._msdcs.<domain>` | **Kerberos** — AD authentication |
| `ms-sccm*.<domain>` | **SCCM/MECM** — System Center client |
| `yd-kscws*.<domain>` | **Kaspersky Security Center** — Admin server |
| `yd-kesgtw*.<domain>` | **Kaspersky Endpoint Security** — Gateway |
| `yd-epomwg*.<domain>` | **Kaspersky** — Enterprise Protection gateway |
| `wpad.<domain>` | **WinHTTP** — Web Proxy Auto-Discovery |
| `wpad*.<domain>` | **WinHTTP** — Proxy auto-detection |
| `isaweb.<domain>` | **ISA Server/TMG** — Legacy proxy/firewall |
| `sr-asc*.<domain>` | **App Controller** — Internal service |

### Add Rewrites to Silence Them

Adding a rewrite to `0.0.0.0` makes AdGuard respond **instantly** (0ms, no upstream
query) instead of waiting for NXDOMAIN from the external DoH. The client gets
`0.0.0.0` — functionally identical to NXDOMAIN for the user, but zero latency
and zero upstream bandwidth.

```bash
# Login
curl -s -X POST http://127.0.0.1:3000/control/login \
  -H 'Content-Type: application/json' \
  -d '{"name":"admin","password":"<password>"}' \
  -c /tmp/agc.txt > /dev/null

# Add rewrites for whole zones
curl -s -b /tmp/agc.txt -X POST http://127.0.0.1:3000/control/rewrite/add \
  -H 'Content-Type: application/json' \
  -d '{"domain":"<domain>","answer":"0.0.0.0"}'

# Add specific servers
for d in \
  ms-sccmmsk001.bee.vimpelcom.ru \
  yd-kscws001.bee.vimpelcom.ru \
  wpad.bee.vimpelcom.ru; do
  curl -s -b /tmp/agc.txt -X POST http://127.0.0.1:3000/control/rewrite/add \
    -H 'Content-Type: application/json' \
    -d "{\"domain\":\"$d\",\"answer\":\"0.0.0.0\"}"
done
```

**Wildcard behavior**: adding a rewrite for `zone.com` catches all subdomains
(`*.zone.com`). Adding `bee.vimpelcom.ru` covers `ms-sccmmsk001.bee.vimpelcom.ru`
and any future subdomains.

### Persist to YAML

```python
import yaml

rewrites = [
    {"domain": "bee.vimpelcom.ru", "answer": "0.0.0.0"},
    {"domain": "ms-sccmmsk001.bee.vimpelcom.ru", "answer": "0.0.0.0"},
    {"domain": "wpad.bee.vimpelcom.ru", "answer": "0.0.0.0"},
    # ... add all corporate domains
]

with open('/opt/AdGuardHome/AdGuardHome.yaml') as f:
    cfg = yaml.safe_load(f)
cfg['filtering']['rewrites'] = rewrites  # or extend existing
with open('/opt/AdGuardHome/AdGuardHome.yaml', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False)
```

### When NOT to Block

If you are **actively debugging** corporate network access through the VPN, leave
these queries alone — NXDOMAIN vs 0.0.0.0 tells you whether the internal DNS
zone is reachable (if a rewrite returns 0.0.0.0 instantly, you can't distinguish
'an actual internal server is answering' from 'AdGuard is lying'). Only add
rewrites after confirming these servers are definitely unreachable from the VPS's
public IP.

## DNS Query Log Forensics

AdGuard's query log can be used to identify **what services are running on a
Windows workstation** behind the VPN, just by analyzing DNS patterns:

| DNS Pattern | Likely Software | 
|-------------|-----------------|
| `_ldap._tcp.*._msdcs.<domain>` | Domain-joined Windows (NetLogon) |
| `_kerberos._tcp.*._msdcs.<domain>` | AD Kerberos authentication |
| `ms-sccm*` | Microsoft SCCM/MECM client |
| `ccm-*` or `sms-*` | ConfigMgr client |
| `yd-ksc*`, `yd-kes*`, `yd-epom*` | **Kaspersky** Security Center / Endpoint |
| `wpad.*` | Windows automatic proxy discovery |
| `isaweb.*` | Microsoft ISA/TMG proxy (legacy) |
| `sr-asc*` | App Controller / internal service |
| `*-print*` | Print servers |
| `*-sccm*` | System Center |

**Typical NXDOMAIN flooding**: a domain-joined Windows machine outside the
corporate network generates 100-500+ NXDOMAIN queries/hour trying to reach
unreachable internal services. The query interval tells you which service is
most aggressive:
- Every 5-15 min → NetLogon (AD secure channel check)
- Frequent bursts → SCCM client polling
- Continuous → Kaspersky agent trying to sync

## Verification Checklist

- [ ] `systemctl status AdGuardHome` — active (running)
- [ ] `ss -tlnp | grep -E '53|3000'` — AdGuardHome listening on both
- [ ] `python3 -c "import socket; print(socket.getaddrinfo('doubleclick.net',80)[0][4][0])"` — returns 0.0.0.0
- [ ] `python3 -c "import socket; print(socket.getaddrinfo('google.com',80)[0][4][0])"` — returns real IP
- [ ] `systemctl is-active sing-box` — active
- [ ] `cat /etc/resolv.conf` — 127.0.0.1 as first nameserver
- [ ] `iptables -t nat -L PREROUTING -n -v 2>&1 | grep 'REDIRECT.*53'` — rules present
- [ ] curl API: filter status shows rules_count > 100k
- [ ] *Optimization:* `systemctl status unbound` — active (running)
- [ ] *Optimization:* `dig @127.0.0.1 -p 5353 google.com +short` — returns real IP
- [ ] *Optimization:* `curl -s http://127.0.0.1:3000/control/dns_info -b /tmp/ag.txt | python3 -c 'import sys,json;print(json.load(sys.stdin)[\"upstream_dns\"])'` — includes 127.0.0.1:5353
- [ ] *Optimization:* cold vs hot benchmark improved
