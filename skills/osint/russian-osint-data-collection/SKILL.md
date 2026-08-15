---
name: russian-osint-data-collection
description: "Use when Bypass bot protection on Russian web sources"
critic_status: done
version: 1.1.0
author: Hermes Agent
tags: [osint, russia, scraping, anti-bot, fuel-prices, tourism, voenkory, energy-warfare]
---
## When to Use

Use when Bypass bot protection on Russian web sources.


# Russian OSINT Data Collection

Techniques for collecting data from Russian and Russia-related web sources that aggressively block headless browsers and automated scraping.

## First Principle: Balanced Sourcing

**ALWAYS search Russian-language sources alongside English/Western sources.** This is not optional — correcting Western-only searches is a recurring pattern. The Russian perspective often contains:
- Different factual claims (e.g., 42.74% refinery damage from Ukrainian General Staff vs 3% from Reuters)
- Operational details not reported in Western media (e.g., systematic АЗС strikes confirmed by voenkory)
- Different threat models and strategic logic

**Minimum search set for any energy-warfare / military logistics analysis:**
1. **en.Wikipedia** — general timeline, Western-sourced narrative
2. **ru.Wikipedia** — separate article with different data and emphasis. Often has different article titles for the same topic.
3. **Russian voenkory** (Поддубный, Рыбарь, Котенок, Коц, Два майора, Онуфриенко, Colonelcassad, Безсонов, ВЗГЛЯД МАКСА, WarGonzo, Операция Z, Рожин)
4. **Минобороны РФ сводки** — via Readovka or mil.ru
5. **Reuters/Bloomberg** — Western commodity/energy market data
6. **Минэнерго/Новак statements** — Russian official position on fuel crisis

## Problem

Major Russian/commercial sources (TASS, Reuters, Росстат, СПбМТСБ) use:
- **DataDome** (Reuters) — advanced bot detection with CAPTCHA
- **ServicePipe** (TASS) — JS challenge before content loads
- **Cloudflare / WAF** — various anti-bot measures
- **TLS fingerprinting** — blocks basic curl/requests

## Solution Layers

### Layer 0: Always try direct browser first
The built-in browser tools (Camoufox) work for some sources:
**Kommersant** — works with headless browser
**Benzin-price.ru** — works (old-school HTML, no bot protection)
**EMISS** (fedstat.ru) — works for government statistics

### Layer 1: curl_cffi (TLS impersonation)
```bash
pip install --system curl_cffi
```
```python
from curl_cffi import requests
r = requests.get(url, impersonate='chrome120', timeout=15)
```
**Passes:** TLS fingerprint checks (TASS returns 200 instead of 403)
**Fails on:** JS challenges (ServicePipe on TASS, DataDome on Reuters), CAPTCHAs

### Layer 2: Playwright + stealth (browser automation)
Install on VPS:
```bash
npm install playwright puppeteer-extra-plugin-stealth@2.11.2
npx playwright install chromium
npx playwright install-deps chromium
```
**Passes:** Initial requests to some DataDome sites (Reuters main page)
**Fails on:** Repeat requests from same IP — DataDome burns IPs after first request
**Limitation:** VPS IPs (datacenter) are quickly flagged

### Layer 3: Residential proxies / real browser bridges
- **Browserbase** — cloud browsers with residential proxies, CAPTCHA solving, stealth
  Config: `BROWSERBASE_API_KEY` + `BROWSERBASE_PROJECT_ID` in `.env`
- **Kimi WebBridge** — real Chrome/Edge browser controlled via MCP protocol
  Requires: Chrome extension + local service running
  Connect via Hermes: `hermes mcp add kimi-webbridge --command "..."`

### Telegram Web Access (t.me/s/{username})

**Works for some channels, not others.** The Telegram web public view at `t.me/s/{username}` loads channel content without authentication for public channels.

**Working channels tested (July 2026):**
- @rybar (1.53M subscribers) — loads fully, rich text posts. Topics: daily СВО сводки, АЗС strikes ("10+ АЗС в день"), ГРС/газ, НПЗ, FSB counter-sabotage, NATO summits.
- @sashakots (479K, verified) — loads fully, long posts. Topics: "Дегазификация Украины" (gas infrastructure), Konstantinovka battle, foreign media, humanitarian aspects.
- @RVvoenkor (1.46M) — loads fully, text+video. Topics: Crimea blackouts, VPK strikes in Kyiv (Буревестник, Киев-71/79, Квант, Жуляны), FSB counter-terror, TofF exercises.
- @dolgarevaanna (28.8K) — cultural/literary channel. NOT relevant for energy-warfare.
- @wargonzo — mostly video content (text not extractable via browser).

**Non-working channels (via t.me/s/):**
- @colonelcassad — times out; use MAX.ru direct post links instead
- @fighterbomber — redirects to contact page (app/bot required)
- @sladkovplus — redirects to contact page (private/restricted)

**Note:** The t.me/s/ view shows only the last ~10 posts. No pagination available.

**Collection method:**
```javascript
var posts = document.querySelectorAll('.tgme_widget_message_wrap');
var results = [];
posts.forEach(function(p) {
    var textEl = p.querySelector('.tgme_widget_message_text');
    var dateEl = p.querySelector('.tgme_widget_message_date');
    var date = dateEl ? dateEl.textContent.trim() : '';
    var text = textEl ? textEl.textContent.substring(0, 300) : '';
    if (text.length > 20) results.push({date: date, preview: text.substring(0, 200)});
});
JSON.stringify(results);
```

### MAX.ru Post Content Extraction

MAX.ru is a Russian microblogging platform. Channel pages (`max.ru/{username}/`) require app download. However, **individual post pages** `max.ru/{username}/{post-id}` render preview content via Open Graph meta tags that can be extracted without authentication.

**Access pattern:**
1. Navigate to `max.ru/{username}/{post-id}`
2. Extract from OG meta tags via browser_console:
```javascript
document.querySelector('meta[property="og:description"]')?.content // full text (truncated)
document.querySelector('meta[property="og:title"]')?.content      // author/channel
document.querySelector('meta[property="og:image"]')?.content      // media
```
3. Also try clicking "Открыть в браузере" (web.max.ru) which sometimes renders full post text without auth.

**Known working channels (confirmed via direct post links):**
- @epoddubny (Поддубный) — fuel logistics, АЗС strikes
- @Mikle1On (Онуфриенко) — strategic analysis, VKS critique
- @dva_majors (Два майора) — АЗС tactics, operator manuals
- @voenkorKotenok (Котенок) — АЗС strike footage
- @colonelcassad (Рожин) — MoD summaries, mass drone attacks
- @NeoficialniyBeZsonoV (Безсонов) — railway infrastructure (>200 locomotives)
- @makslifeoff (ВЗГЛЯД МАКСА) — political EU-Russia analysis

**Limitation:** Only individual post pages work. Channel timeline requires app authentication.

### Readovka News Search

Readovka (readovka.news) is reliable for Минобороны сводки and voenkory reposts. Search at `/search/{URL-encoded-query}/`.

**Effective search terms for energy warfare:**
- `уничтожение АЗС` — gas station destruction
- `топливная логистика` — fuel logistics
- `топливно-энергетический комплекс` — fuel-energy complex
- `склады ГСМ` — fuel depots
- `железнодорожная инфраструктура` — railway
- `массированный удар` — mass strike
- `Минобороны` + `АЗС` — MoD reporting on АЗС strikes

Shows result count ("Найдено N материалов"). Cookie consent modal appears once — dismiss with click on "Я согласен".

## Sources That Actually Work

| Source | Access Method | Notes |
|---|---|---|
| benzin-price.ru | Direct browser | Old HTML, no bot protection |
| SPIMEX (spimex.com) | Direct browser | Exchange wholesale prices |
| EMISS (fedstat.ru) | Direct browser | Government statistics |
| Kommersant | Direct browser | Weak headless detection, reliable |
| RBC (rbc.ru) | Direct browser | JS-heavy. Navigation unreliable — use direct URLs. Search works but results may be generic. |
| Readovka (readovka.news) | Direct browser | Минобороны сводки, voenkory. Searchable. |
| MAX (max.ru) | Direct browser (individual posts only) | Russian voenkory. OG meta-extraction works. |
| Dzen News (dzen.ru/news) | Direct browser | Aggregated headlines from Russian sources. |
| Reuters Energy | Playwright (1-shot) | Burned after first request from same IP. |

## Sources That Are Blocked

| Source | Block Type |
|---|---|
| TASS | ServicePipe + IP block ("Forbidden") |
| RIA Novosti | JS challenges (articles 404) |
| Yandex Search/Captcha | SmartCaptcha |
| Izvestia | Browser check loop |
| Mil.ru | TLS/certificate error |
| Telegram Web (t.me) | Timeout |

## Report Formatting for .txt Files

For analytical reports saved as .txt files:

- **NO pipe/bar tables (`|` delimiter)** — alignment shifts in plain text make them unreadable.
- Use **structured lists** with bullet points (`•`) for multi-column data.
- Use **ALL CAPS headers** with `=====` underline separators between sections.
- For tabular data, use dashed lines + alignment by spaces:
```
Показатель          До кампании    После
--------------------------------------------------------
Переработка нефти  5.4 млн б/сут  -3% (Reuters)
```
- **NO anglicisms** in body text. Replace: JIT → «точно вовремя», Middle Strike Campaign → Кампания ударов средней дальности, disruption → сбой/нарушение, attrition → истощение, trade-off → компромисс/обмен. Source NAMES (Reuters, Bloomberg, OSINT) keep English.
- Reports should be self-contained: include sources section listing all channels and data sources used.

## Energy Warfare Analysis Framework

### Target taxonomy (Украина → Россия):
1. **НПЗ** (refineries) — primary, >21 of 38 large refineries hit
2. **Ports/export terminals** — Ust-Luga, Primorsk, Novorossiysk, St. Petersburg Oil Terminal
3. **Pipelines/pumping stations** — KTK (CPC), Andreapol, Novovelichkovskaya
4. **Fuel depots** — Engels, Liskinskaya, Lyudinovo, etc.
5. **Railway fuel logistics** — fuel trains, locomotives

### Target taxonomy (Россия → Украина):
1. **АЗС** (gas stations) — systematic campaign. Scale: "10+ АЗС per day" (Рыбарь). 7+ voenkory confirm (Поддубный, Два майора, Онуфриенко, Котенок, Рыбарь, Коц, Операция Z).
2. **Gas infrastructure** — "Дегазификация" campaign (Коц): ГРС (Gazoprovodnoye, Nizhyn, Nosovka), Naftogaz facilities in Poltava/Kharkiv/Sumy regions.
3. **Fuel logistics** — fuel trucks, tankers, supply convoys. GSM depots: Vyshneve, Zaporizhzhia, Kharkiv.
4. **Railway infrastructure** — locomotives (>200 destroyed in 2026 per Безсонов), stations, tracks, fuel trains. Systematic campaign.
5. **Power generation** — ТЭЦ, ГЭС, substations (social repression strategy).
6. **VPK (defense industry)** — production facilities for drones and missiles. Confirmed strikes: завод «Буревестник», «Киев-71», «Киев-79», «Квант», ракетный завод в Жулянах (ракеты «Нептун»). Delivered as combined retaliation strikes.

### Analytical dimensions per target type:
- Geography — specific locations hit
- Weapon used — Geran-2/4, Kh-101, Kalibr, Iskander
- Scale — single target vs mass strike (e.g., "10+ АЗС in one day", "625 drones in one night")
- Strategic logic — operational vs tactical, military vs civilian
- Effectiveness — disruption duration, reparability

### Key source triage:
1. Russian voenkory via Telegram web (t.me/s/{username}) or MAX.ru direct links
2. Минобороны РФ сводки via Readovka (searchable)
3. Wikipedia (en + ru — often differ significantly on same topic)
4. Industry data: Reuters, Bloomberg
5. Генштаб ВСУ vs российские источники (often diverge 3x in same claim)

### Internal Russian debates to track:
- АЗС vs bridges across Dnieper — which is higher priority? (Онуфриенко: АЗС отвлекают от мостов; Два майора: АЗС критически важны)
- Proxy war vs total war thresholds
- VKS vs drone operators — institutional conflict over targeting priorities

## Sun Tzu Strategic Assessment Framework

When asked for strategic analysis, apply Sun Tzu across these dimensions:

1. **Pre-war calculation** — was victory assured before the war began?
2. **Economic warfare vs positional** — Sun Tzu ranks city sieges worst; Russia chose them as primary tactic.
3. **Dividing enemies** — Russia united Europe/USA against itself instead of making separate energy deals (Germany, Hungary, Slovakia).
4. **Striking weakness vs strength** — Ukraine's Middle Strike Campaign (supply lines) is Sun Tzu-correct; Russia's city battles are not.
5. **Speed vs protraction** — 4-year war violates Sun Tzu's core principle.
6. **Leaving the enemy an exit** — cornering Ukraine increases resistance; negotiated settlement with real guarantees would reduce it.

The standard diagnosis: Russia failed at every level of Sun Tzu's framework. The current course (neither victory nor peace) is the worst option.

## Known IP Status
- WSL IP (84.18.97.111): Blocked by TASS, Yandex, Izvestia. Dzen/Readovka/RBC work.
- VPS 204.77.1.107: Blocked by DataDome (burned), blocked by TASS
- VPS 45.134.15.185: Not tested for scraping

## Browser Tool Limitations

Camoufox browser runs WITHOUT residential proxies. For Russian sources:
- Aggressive bot protection (TASS, RIA, Izvestia, Yandex) blocks consistently
- Weaker protection (RBC, Kommersant, Dzen) loads but may have JS navigation issues
- RBC pitfall: complex JS same-page anchors. Use direct URLs, not click navigation.
- The browser is most useful for Readovka, MAX.ru individual posts, and Dzen News aggregation.

## Data Sources Reference

See:
- `references/retail-fuel-prices.md` — collecting retail fuel prices from benzin-price.ru
- `references/russian-voenkory-azs-strikes.md` — evidence of Russian voenkory reporting systematic АЗС strikes
