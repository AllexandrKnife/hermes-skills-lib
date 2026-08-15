# Working Russian Retail Sources (2026)

## Confirmed Working (from outside RF)

### stroylandiya.ru
**Method:** curl with Yandex Browser UA
```bash
curl -s -L "https://stroylandiya.ru/search/?q=..." \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 YaBrowser/24.1.0.0 Safari/537.36" \
  --max-time 15
```
**Price extraction:** Price sliders in HTML
```python
slider = re.findall(r'data-min="(\d+)" data-max="(\d+)"', html)
# If data-min == data-max = exact single price
```
**Page size:** ~500-600 KB for search results (includes JS-rendered content)
**Note:** avito rate-limits after 1-2 queries per IP; delegate to subagents for multiple searches.

## Confirmed Working (from within RF)

### saratov.lemanapro.ru
**Note:** Requires Russian IP. Qrator bot protection blocks from outside RF.
Formerly leroymerlin.ru — always use lemanapro.ru, never cite leroymerlin.ru.

### egger-russia.ru
Manufacturer catalog. Shows decor codes and surface structures. **No retail prices.**
Only useful to verify that EGGER H1145 ST10 is a decor code, not a door model.

### tdserver.ru
EGGER LDSP distributor. Shows product specifications, may or may not show prices.

## Confirmed Blocked (from outside RF, 2026)

- petrovich.ru — Qrator, "Доступ временно ограничен"
- vseinstrumenti.ru — captcha challenge
- market.yandex.ru — 403 Forbidden
- lemanapro.ru — Qrator (except from RF IP)
- Google Search, Google Cache — captcha
- Yandex Search — SmartCaptcha

## Bing RSS Workaround (partial)

When Bing HTML search returns Cloudflare challenge, try RSS format:
```
https://www.bing.com/search?q=...&format=rss
```
Extract `<link>` elements. Description text may provide preview content.
Returns generic results for Russian topics (poor relevance).
