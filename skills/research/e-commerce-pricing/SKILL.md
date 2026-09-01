---
name: e-commerce-pricing
version: 1.0.0
description: "Use when Research product prices across Russian"
critic_status: done
tags: [pricing, e-commerce, ozon, wildberries, yandex-market, scraping, duckduckgo, price-comparison]
---

# E-Commerce Pricing Research

Research the cheapest price for a product on Russian e-commerce platforms when the agent's IP is blocked by major sites (Ozon, Yandex, Google).

## When to use

- User asks "найди самую дешёвую цену на [товар]" (find cheapest price for a product)
- User sends an Ozon / Wildberries / Yandex Market link and asks for price comparison
- Any price research task where the primary marketplace may block automated access

## Prerequisites

- Python 3 with `requests` library (standard in Hermes environment)
- No residential proxy required — this workflow works with a blocked IP

## Workflow

### 1. Primary: DuckDuckGo Lite (text-based, no JS) — increasingly blocked

DuckDuckGo's `lite.duckduckgo.com` endpoint used to tolerate automated queries, but as of mid-2026 it **also returns captcha** (the "Unfortunately, bots use DuckDuckGo too" page with image-puzzle challenge). Both `lite.` and `html.` subdomains are affected.

**Always try DDG Lite first** — it may work from some IPs or for some query patterns:

```python
import requests, re

session = requests.Session()
session.headers.update({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
})

url = 'https://lite.duckduckgo.com/lite?q=' + requests.utils.quote('PRODUCT_NAME цена купить')
resp = session.get(url, timeout=15)
text = resp.text
```

**Check for captcha**: if the response contains `anomaly-modal` or `challenge-form` or `"Unfortunately, bots use DuckDuckGo too"`, DDG blocked you. **Move to plan B immediately** — do not retry.

**DDG Lite output format** (when it works): results are in HTML tables. Key extraction patterns:
- Result URLs: `<a href="..." class="result-link">...</a>`
- Snippets: `class="result-snippet"`
- Prices: regex `(\d[\d\s]*[,.]?\d*)\s?(?:₽|руб)`

### 2. Extract prices and URLs (when DDG works)

```python
import html
text = html.unescape(text)

# Find result links
links = re.findall(
    r'<a[^>]*href=[\\'\\\"](https?://[^\\'\\\"]+)[\\'\\\"][^>]*class=[\\'\\\"]result-link[\\'\\\"][^>]*>(.*?)</a>',
    text, re.DOTALL
)

# Find prices in context
target_words = ['цена', 'купить', 'ozon', 'wildberries', 'market', 'brait', 'bsa']  # определить до использования
for line in text.split('\n'):
    clean = re.sub(r'<[^>]+>', '', line).strip()
    if '₽' in clean and any(w in clean.lower() for w in target_words):
        # price found with context
```

Target words for price context: `brait`, `bsa`, `опрыск`, `wild`, `ozon`, `market`, product-specific terms.

### 3. Plan B: Direct HTTP to known retail stores (no search at all)

When ALL search engines are blocked (DDG captcha, Google captcha, Yandex 403), **skip search entirely** and hit known Russian retail URLs directly. This works because many stores serve SSR HTML without bot detection:

**Known-working stores** (return 200 with product data):
- `trial-sport.ru` — large Brotli-compressed SSR pages, content IS there but may exceed 50KB
- `velostrana.ru`, `velo-probega.ru`, `liderstroyinstrument.ru`, `ros-inst.ru`
- Search for `site:FORBIDDEN_SITE PRODUCT_NAME` — once you know the domain, scrape its own search

**Critical: Brotli compression and page size.** Russian retail sites heavily SSR their pages. The response is Brotli-compressed and decompresses to 100K–400K chars of HTML. The `http_fetch` tool's default `maxResponseBytes` often truncates the product body. To cope:

- Set `maxResponseBytes=150000` or higher in http_fetch calls
- Even in truncated HTML, extract what's in the first 15KB: `<title>`, `<meta name="description">`, `<script type="application/ld+json">` are usually in `<head>`
- Price patterns: `(\d[\d\s]*[.,]?\d*)\s?(?:₽|руб)`
- Category from title (e.g. "Шоссейные велосипеды" vs "Горные велосипеды")

**When direct HTTP fails or product data is incomplete**, fall back to **knowledge-based recommendations**:
- Use your training knowledge to recommend models/brands in the price range
- Tell the user what to search for on Avito and what criteria to check
- The user can inspect the live listings themselves — you guide the criteria

### 4. Price triangulation

Cross-reference prices from multiple stores to identify the cheapest offer. For the same product:
- **Wildberries**: URL format `https://www.wildberries.ru/catalog/{ID}/detail.aspx` — blocked (498)
- **Ozon**: URL format `https://www.ozon.ru/product/{slug}-{ID}/` — blocked
- **Yandex Market**: URL format `https://market.yandex.ru/card/{slug}/{ID}` — blocked (403)
- **Avito**: URL format `https://www.avito.ru/all/...` — blocked (firewall/captcha after 1 request)
- **Smaller stores** (trial-sport.ru, vseinstrumenti.ru, liderstroyinstrument.ru, ros-inst.ru, velostrana.ru) — often accessible

**Triangulation rule (пористость + избыток):** минимум 2-3 независимых источника для вывода «самая дешёвая цена»; один источник = «найдено в одном месте», НЕ «минимальная цена». К каждой цене — дата проверки (цены меняются ежедневно). Расхождение источников 2x+ — фиксировать диапазон, не среднее.

**Кэш результата (предв. действие):** сохранять найденные цены с датой (osint-tools cache или /root/Отчёты/); повторный запрос по тому же товару в течение 24ч — сначала кэш, не парсить заново.

### 5. Verify product match

Check that the cheapest offer includes the same specifications/configuration as the user's request:
- Scanner for \"4 насадки\" / \"4шт\" / \"4 сопла\" in the description
- Check battery type (гелевый vs литиевый vs absent)
- Check volume (12 л vs other)

## Pitfalls

- **DuckDuckGo Lite now also blocks**: Both `lite.` and `html.` subdomains return image-puzzle captcha. Check for `anomaly-modal` in response. Do not retry — move to plan B.
- **Avito blocks on first request**: Returns firewall/captcha page after 1-2 requests from the same IP. Don't waste retries.
- **Ozon blocks everything**: Even the homepage returns \"Похоже, нет соединения\". DDG Lite may still show Ozon links — you can extract the product ID from the URL, but cannot get the live price from Ozon directly.
- **Yandex 403**: Yandex and Yandex Market return 403 with \"доступ временно запрещён\" from this IP range. Don't waste time retrying — skip to the next store.
- **Google CAPTCHA**: Google redirects to `consent.google.com` or `sorry/index`. Already blocked — skip.
- **Brotli (br) compressed pages**: http_fetch transparently decompresses br-encoded content, but the resulting HTML is huge (100-400KB). Response may be truncated. Set higher `maxResponseBytes` or extract what's in `<head>`.
- **HTML encoding**: Russian text in DDG Lite results uses HTML entities. Always call `html.unescape()` before regex extraction.
- **403 ≠ no data**: Some stores return full page with 200 even when bigger marketplaces return 403. Always try direct requests to stores found in search results.
- **Timeout**: Set timeout=15 for DDG Lite, timeout=10 for individual stores. Don't let slow stores block the pipeline.
- **Wildberries**: Returns 498 (bot detection) from this IP. Don't retry.
- **browser_act degraded without page-agent**: `browser_act` returns `degraded: true` with `"page-agent not installed"`. Do not attempt browser automation without verifying page-agent is installed first.
- **When literally all search/web scraping fails**: Give knowledge-based recommendations directly. Tell the user what to search for and what criteria to check — let them inspect live listings themselves.

## References

See `references/ozon-price-research.md` for session-specific examples and reproduction recipes.

## Related skills

- `domain-investigation` — for WHOIS/DNS/HTTP profiling of store domains
