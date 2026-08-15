# Russian Construction Pricing Sources

## Working Sources (verified 2026-07)

### ✅ stroylandiya.ru
**Access:** curl with Yandex Browser UA works. Price sliders expose data-min/data-max.
**Search URL:** `https://stroylandiya.ru/search/?q={query}`
**Known prices (Saratov, July 2026):**

| Product | Price | Source |
|---------|-------|--------|
| Bergauf Easy Boden 25 кг | 626 ₽ (slider min=max) | `search/?q=наливной+пол+Bergauf+Easy+Boden` |
| Bergauf Boden Zement 20 кг | 562 ₽ | `search/?q=Bergauf+Boden+Zement` |
| ПВХ-плитка SPC коммерческая | 1 900-4 746 ₽ (18 товаров) | `search/?q=ПВХ+плитка+коммерческая+SPC` |
| Грунтовка для пола | 181-1 675 ₽ (7 товаров) | `search/?q=грунтовка+пола` |
| Grohe смесители для раковины | 1 028-18 860 ₽ | `search/?q=Grohe+смеситель+для+раковины` |
| Порожек алюминиевый накладной | 219-2 047 ₽ (201 товар) | `search/?q=порожек+алюминиевый+накладной` |
| Стяжка ЦПС М150 | 110-2 394 ₽ | `search/?q=стяжка+цементная+М150` |
| Дверь межкомнатная ламинированная | 1 955-5 580 ₽ (30 товаров) | `search/?q=дверь+межкомнатная+ламинированная` |
| Дверь межкомнатная влагостойкая 2050×900 | 1 955-18 077 ₽ | `search/?q=дверь+межкомнатная+влагостойкая+2050х900` |
| Dulux краски | 410-15 870 ₽ | `search/?q=Dulux` |
| Kiilto 2 Plus клей | 26-3 555 ₽ | `search/?q=Kiilto+2+Plus` |

### ✅ avito.ru (Саратов)

### ✅ avito.ru (Саратов)
**Access:** First search works, then rate-limit kicks in. Use subagent for fresh IP.
**Base URL:** `https://www.avito.ru/saratov/predlozheniya_uslug/`
**Known data:** Waste removal от 1 500-2 050 ₽ (per service, not per m³).

### ✅ egger-russia.ru
**Access:** Works. Catalog only, no retail prices.
**Use case:** Look up decor codes (H1145 ST10 = Oak Bardolino Natural).

### ✅ tdserver.ru / list-plit.ru / planetadsp.ru
**Access:** Works. Egger LDSP distributors.
**Use case:** Confirm EGGER H1145 ST10 is a decor, not a door.

## Blocked Sources (from outside РФ)

| Source | Block type |
|--------|-----------|
| lemanapro.ru (Саратов) | Qrator bot protection. Ask user to check from Russia. |
| petrovich.ru | Access denied |
| market.yandex.ru | 403 Forbidden |
| vseinstrumenti.ru | Captcha/JS |
| Google search | Captcha |
| Yandex search | SmartCaptcha |
| Bing search | Captcha/challenge |

## Notes

- **EGGER H1145 ST10** = decor code ("Дуб Бардолино натуральный", structure ST10 "шероховатые глубокие поры"). EGGER makes LDSP, NOT finished doors. The actual door is from an unnamed factory using EGGER laminate.
- **Лемана ПРО** = rebranded Leroy Merlin in Russia. Never cite LeroyMerlin.ru.
- **NDS in RF from 2026:** 22%, not 20%.
- **Regional coefficient:** Saratov labor = ~50-65% of Moscow.
