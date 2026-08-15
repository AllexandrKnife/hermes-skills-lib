# Unbound + Parallel Upstreams — Worked Example

Concrete commands used during setup on 45.134.15.185 (Ubuntu 22.04).

## Install unbound

```bash
apt-get install -y unbound python3-yaml
```

## Unbound config: /etc/unbound/unbound.conf.d/aggressive.conf

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

**Do NOT add `auto-trust-anchor-file`** — Ubuntu 22.04 already ships
`/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf` with:
```
auto-trust-anchor-file: "/var/lib/unbound/root.key"
```

## Download root.hints

```bash
wget -q -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
chown -R unbound:unbound /var/lib/unbound/
```

## Validate and start unbound

```bash
unbound-checkconf /etc/unbound/unbound.conf
systemctl restart unbound
systemctl status unbound --no-pager -l
```

Expected: `Active: active (running)`, modules: subnet, validator, iterator.

## Update AdGuardHome.yaml

```python
import yaml

with open('/opt/AdGuardHome/AdGuardHome.yaml', 'r') as f:
    cfg = yaml.safe_load(f)

dns = cfg['dns']
dns['upstream_dns'] = [
    '127.0.0.1:5353',
    'https://dns10.quad9.net/dns-query',
    'https://dns.cloudflare.com/dns-query',
    'https://dns.adguard-dns.com/dns-query'
]
dns['upstream_mode'] = 'parallel'
dns['cache_size'] = 67108864        # 64 MB (was 4 MB)
dns['bootstrap_dns'] = ['9.9.9.10', '149.112.112.10', '1.1.1.1', '2620:fe::10']

with open('/opt/AdGuardHome/AdGuardHome.yaml', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False)
```

## Restart AdGuardHome (with port 53 conflict check)

```bash
# Check if anything is on port 53
ss -tlnp | grep ':53 '
ps aux | grep -i adguard | grep -v grep

# If old manually-started AdGuardHome is running: kill it
kill <PID>

# Then start via systemd
systemctl start AdGuardHome
systemctl status AdGuardHome --no-pager -l
```

## Verify

```bash
dig @127.0.0.1 google.com +short          # → real IPs (AdGuard works)
dig @127.0.0.1 doubleclick.net +short     # → 0.0.0.0 (blocked)
dig @127.0.0.1 -p 5353 google.com +short  # → real IP (unbound direct)
```
