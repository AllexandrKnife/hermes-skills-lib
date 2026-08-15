# Free IOC Enrichment Sources — matrix

Reachability verified 2026-08 from a RU VPS (1 vCPU, 957 MiB). All times are
"worked in a real enrich run on that box".

## Keyless (work out of the box)

| Source | Endpoint | What you get | Quota | Notes |
|---|---|---|---|---|
| ip-api | `http://ip-api.com/json/<ip>?fields=status,country,city,isp,org,as,asname,proxy,hosting,mobile` | geo, ISP, ASN, proxy/hosting flags | 45 req/min | HTTP only on free tier (HTTPS is paid). `proxy:true` is a real signal — Tor exits, VPNs. AS60729 Stiftung Erneuerbare Freiheit = Tor |
| dns.google (DoH) | `https://dns.google/resolve?name=<domain>&type=<A|AAAA|MX|NS|TXT>` | full DNS records | unlisted | parse `Answer[].data` |
| URLhaus feed | `https://urlhaus.abuse.ch/downloads/text/` (GET, plain text) | live malicious URL list | refresh ≥ every 5 min, we use 10 min TTL | The JSON API now REQUIRES an auth key (auth.abuse.ch) and returns empty body otherwise — use the feed instead. Match by exact URL / host / IP; beware `\r` from CRLF lines |
| MalwareBazaar | `https://mb-api.abuse.ch/api/v1/` POST `{query:get_info, hash}` | hash → signature, file type, tags, first/last seen, ClamAV intel | 1 req/s | 401 Unauthorized without MALWAREBAZAAR_API_KEY as of 2026-08 (previously keyless) |

## Keyed (opt-in via env var; free tiers)

| Source | Endpoint | What you get | Free quota | Env var |
|---|---|---|---|---|
| VirusTotal | `https://www.virustotal.com/api/v3/<ip_addresses|domains|urls|files>/<ioc>` | detection stats (malicious/suspicious/undetected), reputation, tags | 4 req/min, 500/day | VT_API_KEY |
| AbuseIPDB | `https://api.abuseipdb.com/api/v2/check?ipAddress=&maxAgeInDays=90` header `Key:` | abuseConfidenceScore, totalReports, categories, usageType | 1000/day | ABUSEIPDB_API_KEY |
| AlienVault OTX | `https://otx.alienvault.com/api/v1/indicators/<ip|domain|hash>/<general|analysis>` header `X-OTX-API-KEY` | pulse names/tags/adversary, reputation | 10/min | OTX_API_KEY |
| Shodan | `https://api.shodan.io/shodan/host/<ip>?key=` | ports, services, vulns (CVE keys), hostnames, OS | 50 credits | SHODAN_API_KEY |
| GreyNoise | `https://api.greynoise.io/v3/community/<ip>` header `key:` | classification (malicious/benign/unknown), noise, riot | 50/day | GREYNOISE_API_KEY |
| HIBP | `https://haveibeenpwned.com/api/v3/breachedaccount/<email>` header `hibp-api-key` | breach list (404 = clean) | 2 req/s | HIBP_API_KEY |

> urlscan.io (`URLSCAN_API_KEY`) — НЕ реализован в enrich.py (2026-08): в SOURCES отсутствует,
> RateLimiter удалён. Не ждать его работы, пока не будет добавлен в код.

## Scoring weights (enrich.py)

- VirusTotal: `min(0.5, malicious/total * 2)` — 25% detections = 0.5 (cap)
- AbuseIPDB: `confidence/100 * 0.3`
- URLhaus feed hit: +0.3
- MalwareBazaar hit: +0.3
- OTX: `min(0.15, pulse_count * 0.05)`
- GreyNoise malicious: +0.2
- ip-api proxy/hosting: +0.1 (weak signal, raises Tor/VPN exits above 0)

Verdict: ≥0.6 MALICIOUS, ≥0.25 SUSPICIOUS, else CLEAN.

## Feed-monitoring pattern (MISP without MISP)

Instead of hosting MISP, consume its public feeds by URL and diff against a
watchlist in a cron job:
- URLhaus plain text: `https://urlhaus.abuse.ch/downloads/text/`
- ThreatFox: `https://threatfox.abuse.ch/export/json/recent/` (needs key)
- abuse.ch MISP events: `https://urlhaus.abuse.ch/downloads/misp/`
Pattern: fetch → cache to file with TTL → match watchlist → alert on new hits
to Telegram. Same for any MISP/TAXII feed the user is authorized to consume.

## Resource-fit notes

- These platforms do NOT fit a 1 vCPU / 957 MiB box: OpenCTI (8 vCPU/16 GB min, RabbitMQ+Redis+MinIO+OpenSearch), IntelOwl (~4 GB, Django+Celery+Postgres+Redis+RabbitMQ), MISP (2-3 GB, PHP+MariaDB+Redis).
- A single-process Node/Python tool fits: this enrich.py (~100 MB), SpiderFoot (~150-300 MB).
- If the user truly needs a TIP platform: VPS upgrade to 4 GB is the honest recommendation.
