# AdGuardHome Filter Tuning — Reference

## Recommended Blocklist Setup

| # | Name | URL | Rules | Priority |
|---|------|-----|:-----:|:--------:|
| 1 | AdGuard DNS filter | `https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt` | ~158k | **must** |
| 2 | AdAway Default | `https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt` | ~100k | recommended |
| 3 | OISD | `https://big.oisd.nl/` | ~327k | **must** |
| 4 | HaGeZi Multi | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/multi.txt` | ~431k | recommended |

Total enabled: **~1M rules**. Typical block rate: 15-25%.

## Persisting API-Added Filters to YAML

The `control/filtering/add_url` API adds filters at runtime only. On restart,
they are lost unless written to `AdGuardHome.yaml`. Use this script to merge:

```python
import json, yaml

# Fetch runtime filter status
# (run via SSH: curl -s -b /tmp/agc.txt http://127.0.0.1:3000/control/filtering/status)

cfg_runtime = json.loads('...')  # paste output here

with open('/opt/AdGuardHome/AdGuardHome.yaml') as f:
    cfg = yaml.safe_load(f)

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
        for ef in cfg['filters']:
            if ef['url'] == rf['url']:
                ef['enabled'] = rf['enabled']

with open('/opt/AdGuardHome/AdGuardHome.yaml', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False)
```

## Test Domains

Use these to verify filter coverage after tuning:

| Domain | Expected | Notes |
|--------|:--------:|-------|
| `google.com` | resolved | Sanity check |
| `doubleclick.net` | 0.0.0.0 | Standard ad domain |
| `ad.doubleclick.net` | 0.0.0.0 | Subdomain variant |
| `analytics.google.com` | 0.0.0.0 | Analytics tracker |
| `pagead2.googlesyndication.com` | 0.0.0.0 | Google Ads |
| `adsrvr.org` | 0.0.0.0 | The Trade Desk |
| `adzerk.net` | 0.0.0.0 | Ad serving |
| `scorecardresearch.com` | 0.0.0.0 | ComScore (hard to block) |
| `outbrain.com` | 0.0.0.0 | Content recommendation |
| `taboola.com` | 0.0.0.0 | Content recommendation |
| `amazon-adsystem.com` | 0.0.0.0 | Amazon ads |
| `criteo.com` | 0.0.0.0 | Retargeting |
| `adnxs.com` | 0.0.0.0 | AppNexus/Xandr |
| `pubmatic.com` | 0.0.0.0 | SSP (hard to block) |
| `openx.net` | 0.0.0.0 | SSP (hard to block) |
| `appnexus.com` | 0.0.0.0 | DSP |
| `adform.com` | 0.0.0.0 | Ad management |
| `doubleverify.com` | 0.0.0.0 | Ad verification |

Domains that still resolve after all 4 filters enabled may need custom user rules.

## Block Rate Targets

| Environment | Target block rate | Comment |
|:------------|:----------------:|:--------|
| General browsing | 15-25% | Healthy |
| OSINT research | 10-20% | Some targets require real ad resources |
| Minimal/clean | 5-10% | Only essential blocks |
| Below 5% | fix | Filter not working or very narrow |

## AdGuard API Reference (Relevant Endpoints)

All endpoints at `http://127.0.0.1:3000/control/`. Requires session cookie from
`POST /login` with `{"name":"admin","password":"..."}`.

| Endpoint | Method | Purpose |
|----------|:------:|---------|
| `/login` | POST | Auth, returns session cookie |
| `/filtering/status` | GET | List filters + rules count |
| `/filtering/add_url` | POST | Add new filter by URL |
| `/filtering/remove_url` | POST | Remove filter (send URL as body) |
| `/filtering/set_url` | POST | Update filter properties |
| `/filtering/enable`/`disable` | POST | Enable/disable by ID (may 404 — use YAML edit as fallback) |
| `/filtering/refresh` | POST | Force refresh all filters |
| `/dns_config` | POST | Set upstream_dns, upstream_mode, cache_size |
| `/dns_info` | GET | Read current DNS config |
| `/stats` | GET | Query/blocked counts, avg time |
| `/querylog?limit=N` | GET | Last N queries with reason, domain |
| `/safebrowsing/enable` | POST | Enable phishing/malware protection |
| `/parental/enable` | POST | Enable adult content blocking |

## See Also

- `SKILL.md` — full deployment + optimization guide
- `references/performance-benchmarks.md` — cold vs hot query data
- OISD: https://oisd.nl/
- HaGeZi: https://github.com/hagezi/dns-blocklists
