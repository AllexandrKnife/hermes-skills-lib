# Ozon Price Research — Session Reference

## Task
Find cheapest price for: **Опрыскиватель садовый аккумуляторный ранцевый 12 л BRAIT BSA-12 с 4 насадками**
Ozon link: `https://ozon.ru/t/BYAEdh4` (product ID from URL: `1803551078`)

## What worked

### DuckDuckGo Lite (primary search)
```
GET https://lite.duckduckgo.com/lite?q=BRAIT+BSA-12+опрыскиватель+цена
```
Response: 200, full HTML with results. No captcha, no JS required.

### Direct HTTP to small stores (partial success)
| Store | Status | Price found |
|-------|--------|-------------|
| liderstroyinstrument.ru | 200 | **2 800 ₽** |
| ros-inst.ru | 200 | 4 029 ₽ |
| vseinstrumenti.ru | 403 | — |
| 30top.ru | 200 | no price |

### Wildberries BSA-12Li
```
https://www.wildberries.ru/catalog/216158619/detail.aspx → 498 (blocked)
```
Price from DDG snippet: **4 645 ₽** (BSA-12Li, lithium version)

## What was blocked (from IP 45.134.15.185)

| Site | Response | Notes |
|------|----------|-------|
| ozon.ru | "Похоже, нет соединения" | Even homepage fails |
| market.yandex.ru | 403 | "доступ временно запрещён" |
| google.com | CAPTCHA / consent redirect | |
| yandex.ru | SmartCaptcha | |
| bing.com | Cloudflare challenge | |
| qwant.com | 403 | |
| searx.be | "Verifying your request" | |
| wildberries.ru | 498 | Bot detection |

## Key code patterns used

### Extract DDG Lite results
```python
links = re.findall(
    r'<a[^>]*href=[\'\"](https?://[^\'\"]+)[\'\"][^>]*class=[\'\"]result-link[\'\"][^>]*>(.*?)</a>',
    text, re.DOTALL
)
```

### Find prices in HTML
```python
prices = re.findall(r'(\\d[\\d\\s]*[.,]?\\d*)\\s?(?:₽|руб)', text)
```

### Extract JSON-LD product data
```python
jsonld = re.findall(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', text, re.DOTALL)
```

## Prices found (all for BRAIT BSA-12)

1. **liderstroyinstrument.ru** → **2 800 ₽** (cheapest, гелевый АКБ, 4 насадки ✓)
2. ros-inst.ru → 4 029 ₽ (гелевый АКБ 12В/8Ач)
3. Wildberries (BSA-12Li) → 4 645 ₽ (литиевый АКБ)
4. ВсеИнструменты.ру → от 1 740 ₽ (категория BRAIT, не конкретная модель)

## Verification
Cheapest offer (2 800 ₽) confirmed to include: телескопическая трубка, сменные сопла 4шт, встроенный кислотно-свинцовый аккумулятор 12В.
