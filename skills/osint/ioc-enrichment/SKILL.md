---
name: ioc-enrichment
version: 1.0.0
description: "Use when Enrich IOCs (IP/domain/URL/hash/email)"
critic_status: done
---

# IOC Enrichment (lightweight, self-hosted)

## When to Use

- User hands you an IP/domain/URL/hash/email and wants a quick reputation verdict ("проверь 185.220.101.34")
- User wants to build a self-hosted enrichment tool instead of hosting IntelOwl/MISP/OpenCTI (which need 2-16 GB RAM — do NOT fit a 1 vCPU/957 MiB box)
- Automating IOC checks: cron watch on fresh feeds (URLhaus, ThreatFox) matched against a watchlist
- Any task where multiple TI sources must be queried in parallel and consolidated

## Working Tool

`/root/scripts/enrich.py` — single-file Python (stdlib + requests + sqlite3), ~620 lines. Run:

```bash
cd /root/scripts && python3 enrich.py <ioc>              # human output
cd /root/scripts && python3 enrich.py <ioc> --json       # machine output
```

Output shape (human): `IOC / type / VERDICT / score / EVIDENCE / per-source lines`.
JSON shape: `{ioc, type, verdict, score, reasons[], timestamp, sources{}, errors{}}`.

Verdict thresholds: score >= 0.6 MALICIOUS, >= 0.25 SUSPICIOUS, else CLEAN.

**Вердикт по подтверждению (инверсия, против инфляции):** MALICIOUS требует хотя бы ОДНОГО прямого детекта (VirusTotal detection, URLhaus/MalwareBazaar hit). Косвенные сигналы (proxy, hosting, ASN-флаги, OTX-пульсы) без прямого детекта — максимум SUSPICIOUS, сколько бы их ни набралось. Сумма косвенных признаков не превращает подозрительное в подтверждённо вредоносное.

## Architecture (what the script does)

1. **Type classification** by regex: IPv4 (with octet-range check!), IPv6, domain, URL, SHA256/MD5, email. Unknown → only URLhaus queried.
2. **Parallel fan-out** — ThreadPoolExecutor(max_workers=8), one task per source, 10 s timeout each. A dead source returns `{"error": ...}` and doesn't kill the run (graceful degradation).
3. **Per-source rate limiting** — min-interval throttle (see pitfall #1).
4. **SQLite cache** (~/.cache/enrich_cache.sqlite, 24 h TTL, per-ioc-per-source rows) — repeat lookups are instant, quotas preserved. URLhaus feed itself is cached to /tmp/urlhaus_feed.txt (10 min TTL).
5. **Scoring** — weighted: VT detections 0.5 (ratio-based), AbuseIPDB confidence 0.3, URLhaus feed hit 0.3, MalwareBazaar hit 0.3, OTX pulses 0.05 each (cap 0.15), GreyNoise malicious 0.2, ip-api proxy/hosting 0.1. Evidence strings accumulate per contributing source.
6. **Keyed sources are opt-in** via env vars (VT_API_KEY, ABUSEIPDB_API_KEY, OTX_API_KEY, SHODAN_API_KEY, GREYNOISE_API_KEY, HIBP_API_KEY, MALWAREBAZAAR_API_KEY). Keyless run covers ip-api + DNS DoH + URLhaus feed. MalwareBazaar с 2026-08 требует ключ (401 без него) — keyless-запуск его не покрывает.

## Source matrix (current state, verified 2026-08)

Keyless: ip-api (geo/ASN/proxy flags, HTTP only!), dns.google DoH (A/AAAA/MX/NS/TXT), URLhaus plain-text feed (see pitfall #2). MalwareBazaar hash lookup — REQUIRES MALWAREBAZAAR_API_KEY (401 without key).
Keyed (free tiers): VirusTotal (4 req/min, 500/day), AbuseIPDB (1000/day), OTX (10/min), Shodan (50 credits), GreyNoise (50/day), HIBP, MalwareBazaar. (urlscan упомянут в free-ioc-sources.md, но в enrich.py НЕ реализован — см. ниже.)

Full endpoint/params/quota table: see `references/free-ioc-sources.md`.

## Hermes integration

- On-demand: teach the agent "проверь <ioc>" → run script, format human output. Can wrap as a skill/command.
- Cron: periodic pull of URLhaus/ThreatFox/MISP feeds (abuse.ch) → match against a watchlist file → alert on new hits. This is the MISP-feeds-without-MISP pattern: consume public feeds by URL, don't host the platform.

## Pitfalls (all hit in real sessions — do not re-discover)

1. **Token-bucket rate limiter with rate < 1 deadlocks.** If bucket capacity = rate (tokens/sec) and you wait for `tokens >= 1`, tokens can NEVER reach 1 when rate < 1 (e.g. 0.75/s) → infinite sleep loop. Fix: use a min-interval throttle instead — `interval = 1/rate; sleep(interval - (now - last)); last = now`. Simplest correct rate limiter for sub-1Hz sources.
2. **URLhaus API changed (mid-2026): POST /api/v1/ and /api/ both return 200 with EMPTY body; auth key now REQUIRED** (get one at auth.abuse.ch). Workaround: match against the public plain-text feed `https://urlhaus.abuse.ch/downloads/text/` (no key, ~minutes freshness). Keep the feed cached with TTL; don't refetch every lookup.
3. **First-call feed download bug**: `stat()` on a not-yet-existing cache file raises FileNotFoundError → caught by broad except → returns empty set WITHOUT downloading. Guard with `exists()` before `stat()`. Check fresh-file logic whenever a "download once, cache N min" pattern is added.
4. **File scripts don't get cwd on sys.path** — only `python3 -c` does. Running `/tmp/debug.py` from `/root/scripts` can't `import enrich` → ModuleNotFoundError. Fix: `PYTHONPATH=/root/scripts python3 /tmp/debug.py`.
5. **timeout kill loses buffered stdout** — diagnosing a hang with `timeout N python3 ...` shows nothing when output is buffered and the process is killed. Write debug progress to a FILE with flush(), or use `python3 -u`.
6. **Probe reachability before promising sources** — curl every candidate API first (this server: crt.sh and hybrid-analysis time out, everything else 200/404-ok). A 404 on an API root is fine (endpoint exists); 000 = blocked/unreachable. Don't list sources that can't be reached from the user's network.
7. **bash captures trailing \r from CRLF feeds** — `BADURL=$(curl ... | head -1)` keeps `\r`; strip it before passing as IOC or exact-match fails silently.

## Verification

- Cold run vs cached run: same verdict, cached should return in <1 s.
- Feed match test: take the first URL from the URLhaus feed itself, enrich it → must be SUSPICIOUS with "URLhaus: 1 listed URL(s)".
- Each new source: add to SOURCES list, test standalone via the debug-file pattern (pitfall #5), confirm it doesn't hang the pool.
