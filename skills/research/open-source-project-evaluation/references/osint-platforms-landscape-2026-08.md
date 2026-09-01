# OSINT / Intelligence Platform Landscape (evaluated 2026-08)

Survey produced while evaluating Osiris (simplifaisoul/osiris) and its mature open-source
alternatives. Two distinct niches: **live world-map dashboards** (Palantir-style situational
awareness) and **threat-intelligence platforms** (IOC enrichment / knowledge graphs — no map).

## Live world-map dashboards (direct Osiris analogues)

| Project | License | Stack / deploy | Layers / sources | Fit on 1 GB VPS |
|---|---|---|---|---|
| **World Monitor** (koala73/worldmonitor) | AGPL-3.0 | Web app, self-hostable | 56 layers, 500+ feeds (ACLED/UCDP conflicts, AISStream ships, OpenSky flights, FIRMS fires, markets) | Medium — heavier, but most polished; REST API + MCP + SDKs; free core, Pro $40/mo |
| **Omniscope** (TanishqChamoli/Omniscope-Public) | MIT | CesiumJS globe + Node proxy + PostgreSQL (compose: frontend/proxy/postgres/pgweb) | ~40 layers, live + time-travel playback, AIS spoofing detection, OFAC vessel overlay | Tight — needs Postgres; history retention default 1 day keeps DB tiny |
| **Osiris** (simplifaisoul/osiris) | MIT | Next.js 16 + MapLibre GL, Docker ~220 MB, keyless-first | 16 layers (flights, CCTV, fires, seismic, news, Telegram OSINT, crypto, OFAC) | Yes — lightest of the map dashboards |
| **Crucix** (alexander-schneider/Crucix) | — | `node server.mjs`, Express only, SSE refresh 15 min | 27 sources (GDELT, OpenSky, FIRMS, Safecast radiation, Telegram channels, KiwiSDR) | Yes — minimal deps, Telegram/Discord alerts, optional LLM hookup |

### Osiris specifics (checked 2026-08-02, ~6.6K stars / 1.4K forks, ~3 months old)

- **Hype red flags:** pump-token address in repo description ("We Get 0.5% on Volume Traded
  2nZNHm3Lr9umG3DVrzYwHgktwkuKuJRXqqRqs3ewpump"); fork farm; mono-author.
- **RECON toolkit is a proxy, not a scanner.** `src/app/api/scanner/route.ts` forwards to
  private `SCANNER_URL` (default Tailscale `100.68.100.15:7700`); backend not in repo; without
  `SCANNER_KEY` every scan returns 503. Passive `/api/osint/*` (DNS via Google DoH, WHOIS, IP
  intel via ip-api, OTX threats, BGPView) works keyless.
- Author deliberately removed `deep/ports/banner/traceroute` scan types from the public proxy
  (SSRF-guard + rate limit 5/min by IP) — that is the safety ceiling of the product.
- Value proposition: visual OSINT monitor (conflicts, Telegram geoparsed channels, fires, cables,
  CCTV) in one window. Not a real "free Palantir" — that claim is marketing.

## Threat-intelligence platforms (no map — IOC / knowledge graph)

| Project | License | Stack | Resource minimum | Fit on 1 GB VPS |
|---|---|---|---|---|
| **OpenCTI** (OpenCTI-Platform) | Apache-2.0 | STIX 2.1 graph, 300+ connectors, RabbitMQ/Redis/MinIO/OpenSearch | 8 vCPU / 16 GB (prod 32 GB) | NO |
| **MISP** | AGPL-3.0-ish | PHP + MariaDB + Redis (LAMP) | 4 vCPU / 8 GB (works leaner but not on 1 GB) | NO |
| **IntelOwl** (intelowlproject) | MIT | Django + Celery + Postgres + Redis + RabbitMQ | ~4 GB | NO |
| **SpiderFoot** (smicallef) | MIT | Single Python process, SQLite, web UI :5001 | ~150-300 MB | YES — only full TI-workbench that fits |

### Key positioning notes

- **IntelOwl** = IOC enrichment orchestration (submit observable → fan out to VT/AbuseIPDB/Shodan/
  OTX/URLhaus/MalwareBazaar in parallel → unified report). Value scales with API-key coverage;
  no keys = empty shell. Output connectors to MISP/OpenCTI/DFIR-IRIS.
- **MISP** = IOC sharing platform, 12k+ orgs community. Best for exchanging indicators, not for
  solo analysis.
- **OpenCTI** = knowledge graph + ATT&CK mapping + diamond model; made by Filigran, funded by
  ANSSI. Overkill for a solo operator; the "real Palantir analogue" only if you need actor
  profiling over time.
- **SpiderFoot** = automated attack-surface recon, 200+ modules, correlation graph. Dated UI but
  the only mature TI-workbench deployable on a small VPS.

## Poor-man's IntelOwl (zero-infra pattern, fits anywhere)

Instead of hosting a TI platform, orchestrate enrichment directly from the agent: one script /
cron fires parallel queries to VirusTotal, AbuseIPDB, OTX, URLhaus, MalwareBazaar, Shodan for an
IOC and returns a merged JSON. Covers the solo-operator IntelOwl use-case with free-tier quotas
(hundreds of lookups/day) and no containers. MISP feeds (abuse.ch, CIRCL, Botvrij) can be
consumed via URL/TAXII without hosting MISP.

## Resource-check command (run before any self-hosting recommendation)

```bash
nproc; free -h; df -h /; docker ps --format '{{.Names}} {{.Status}}'
```
