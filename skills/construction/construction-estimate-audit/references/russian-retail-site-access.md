# Russian Retail Site Access — observed blocking behavior

Last updated: 20.07.2026

## Sites that work (from non-Russian IP)

| Site | URL | Behavior | Last verified |
|------|-----|----------|---------------|
| Стройландия (main) | stroylandiya.ru | ✅ Works — full access, catalog pages with prices via data-min/data-max | 23.07.2026 |
| Стройландия (Саратов) | saratov.stroylandiya.ru | ❌ 503 — владелец ограничил доступ. Использовать основной домен. | 23.07.2026 |
| EGGER Russia | egger-russia.ru | ✅ Catalog accessible — manufacturer info only, no retail pricing | 20.07.2026 |
| tdserver.ru | tdserver.ru | ✅ Russian distributor for EGGER products | 20.07.2026 |
| planetadsp.ru | planetadsp.ru | ✅ Russian LDSP distributor | 20.07.2026 |
| list-plit.ru | list-plit.ru | ✅ Russian plate materials distributor | 20.07.2026 |

## Price extraction technique — Stroylandiya slider data

Stroylandiya uses a range slider with data-min/data-max attributes embedded in the HTML. These are NOT JS-dependent and can be extracted with curl + regex, even when the actual product grid is JS-rendered.

**Technique:**
```
curl -s -L "https://stroylandiya.ru/search/?q=[PRODUCT]" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
```
Then regex: `re.findall(r'data-min="(\d+)" data-max="(\d+)"', data)`

When min == max, it's a single price for exactly one product found.
When min != max, it's the price range across all found products.
When 0 товаров is in the search results but the slider still has values, ignore the slider data.

**Confirmed prices via this technique (20.07.2026):**
| Product | Price | товаров |
|---------|-------|---------|
| Bergauf Easy Boden 25 кг | 626 руб | 1 |
| Bergauf Boden Zement 20 кг | 562 руб | — |
| Kiilto 2 Plus клей | 26 - 3 555 руб | — |
| ПВХ-плитка SPC | 1 900 - 4 746 руб | 18 |
| Стяжка ЦПС М150 | 110 - 2 394 руб | — |
| Dulux Bindo 7 | 410 - 15 870 руб | — |
| Grohe смесители | 1 028 - 18 860 руб | — |
| Алюминиевый порожек | 219 - 2 047 руб | 201 |

## Sites with partial access

| Site | URL | Behavior |
|------|-----|----------|
| Авито | avito.ru | ⚠️ First search (direct URL) works. Subsequent searches from same IP get rate-limited. Use one search at a time. |

## Sites that block non-Russian IPs

| Site | URL | Block type |
|------|-----|------------|
| Лемана ПРО (ex-Leroy Merlin) | lemanapro.ru | ❌ "Отключите VPN" — detects proxy/VPN |
| Яндекс.Маркет | market.yandex.ru | ✅ Works — 200 OK. Цены через grep -oP '\"price\":{\"value\":\\d+' (иногда с лишними нулями). | 23.07.2026 |
| Петрович | petrovich.ru | ❌ QRator bot protection |
| ВсеИнструменты | vseinstrumenti.ru | ❌ Captcha challenge |
| Яндекс.Поиск | yandex.ru | ❌ SmartCaptcha |

## User-provided working URLs (from Russian IP)

When the user in Russia provides a URL from a blocked site, it becomes a confirmed, clickable source. Record it here for reuse.

Key find: EGGER H1145 ST10 furniture panel 15×80×1.6 cm at lemanapro.ru — 716 руб. Confirms this is a decor pattern, not a door model.

## What to tell the user when blocked

> "Следующие сайты заблокировали доступ с моего IP: Лемана ПРО, Яндекс.Маркет, Петрович, ВсеИнструменты, Яндекс.Поиск. Если у вас есть доступ к этим сайтам из РФ, пожалуйста, откройте страницы с ценами на [нужные товары] и пришлите ссылки — я вставлю их в документ."
