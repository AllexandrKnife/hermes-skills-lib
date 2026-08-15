# Saratov Construction Prices — July 2026

Collected 23.07.2026 from working Russian retail sources.

## Stroylandiya (stroylandiya.ru) — Price Slider Data

Search results exposed via `data-min`/`data-max` HTML attributes on price-filter sliders.
When `data-min == data-max`, it's the exact price of the (only) matching product.
NOTE: the regional subdomain saratov.stroylandiya.ru returns 503 since ~July 2026 — use main domain.

### Наливной пол / Self-leveling compound
| Product | Price | Source query |
|---------|-------|-------------|
| Bergauf Easy Boden 20 кг | **626 ₽/шт** (0.75 мешка/м2 при 10мм = 470 руб/м2) | `наливной пол Bergauf Easy Boden 20` |
| Bergauf Boden Zement Medium 20 кг | **562 ₽/шт** | `Bergauf Boden Zement` |

### Стяжка / Screed materials
| Product | Price range | Source query |
|---------|-------------|-------------|
| BERGAUF Erste Grund 25 кг | **377 ₽/шт** | `стяжка пола` |
| BAUPROFFE Основа 25 кг | **306 ₽/шт** | `стяжка пола` |
| ЦПС М150 (стяжка) | 110-2 394 ₽ | `стяжка ЦПС М150` |

### Штукатурка / Plaster
| Product | Price | Source query |
|---------|-------|-------------|
| Knauf Rotband 30 кг | **670 ₽/шт** (8.5 кг/м2 при 10мм = 190 руб/м2) | `Knauf Rotband 30` |

### Клей / Adhesives
| Product | Price range | Source query |
|---------|-------------|-------------|
| Ceresit CM14 25 кг | **471-1 080 ₽** | `Ceresit CM 14` |

### Краски / Paints
| Product | Price range | Source query |
|---------|-------------|-------------|
| Dulux (all types) | 410-15 870 ₽ | `Dulux bindo 7` |
| Dulux Bindo 7 9л (Я.Маркет) | **4 500-6 000 ₽** (расход: ~50 м2/ведро на 2 слоя) | `market.yandex.ru` |

### Потолки / Ceilings
| Product | Price range | Source query |
|---------|-------------|-------------|
| Armstrong Оазис 600×600 | **500-700 ₽/м2** | `Armstrong Оазис 600х600` |
| Профиль Armstrong T24 | 11-4 760 ₽ | `профиль Armstrong T24` |

### ПВХ-плитка / PVC tiles
| Product | Price range | Source query |
|---------|-------------|-------------|
| SPC коммерческая ПВХ-плитка (18 товаров) | 1 900-4 746 ₽/упак | `ПВХ плитка коммерческая SPC` |
| Tarkett Lounge (упаковка ~2м2) | **3 060-4 250 ₽/уп** (= 1 530-2 125/м2) | `Tarkett ПВХ плитка` |

### Керамогранит / Porcelain tile
| Product | Price range | Source query |
|---------|-------------|-------------|
| Керамогранит 595×595 | **от 725 ₽/м2** | `керамогранит 595х595` |

### Межкомнатные двери / Interior doors
| Product | Price range | Source query |
|---------|-------------|-------------|
| Ламинированные двери (30 товаров) | 1 955-5 580 ₽ (полотно) | `дверь межкомнатная ламинированная` |
| Двери влагостойкие 2050х900 | 1 955-18 077 ₽ | `дверь межкомнатная влагостойкая 2050х900` |

### Радиаторы / Radiators
| Product | Price range | Source query |
|---------|-------------|-------------|
| Royal Thermo Biliner 500 | **5 600-10 320 ₽/шт** | `Royal Thermo Biliner 500` |
| Royal Thermo Biliner 10 секц (Я.Маркет) | **8 000-10 000 ₽/шт** | `market.yandex.ru` |

### Сантехника / Plumbing
| Product | Price range | Source query |
|---------|-------------|-------------|
| Grohe смесители для раковины | 732-14 150 ₽ | `Grohe смеситель для раковины хром` |
| Унитаз Santek | **от 1 428 ₽** | `Santek унитаз` |
| Раковина Cersanit 60 см | **от 4 219 ₽** | `Cersanit раковина 60` |
| Плинтус керамогранитный 100мм | **от 126 ₽/м.п.** | `плинтус керамогранитный 100` |

### Прочее / Other
| Product | Price range | Source query |
|---------|-------------|-------------|
| Порожек алюминиевый (201 товар) | 219-2 047 ₽ | `порожек алюминиевый накладной` |
| Плинтус ПВХ 5.5 см | 10-2 012 ₽ | `плинтус ПВХ 5.5 см` |

## Avito (Саратов) — Services pricing (23.07.2026)

| Service | Price | Notes |
|---------|-------|-------|
| Установка межкомнатных дверей | **3 000-4 000 ₽/шт** | Full install with fittings |
| Укладка плитки на стены | **700-1 000 ₽/м²** | Tile work |
| Укладка керамогранита на пол | **700-1 000 ₽/м²** | 595x595 format |
| Демонтаж плитки | **150-300 ₽/м²** | |
| Монтаж унитаза (полный) | **1 000-2 000 ₽/шт** | Assembly + connection |
| Монтаж Armstrong потолка | **300-450 ₽/м²** | Grid + tiles |
| Вывоз мусора | **2 000-3 000 ₽/м³** | |
| Шпаклёвка+покраска (комплекс) | **200-350 ₽/м²** | |
| Монтаж раковины | **1 500-2 500 ₽/шт** | With siphon + mixer |
| Демонтаж дверей | **500-800 ₽/шт** | |

## Avito price extraction technique

Use curl with standard Chrome UA, extract from JSON field:
```bash
curl -s -L "https://www.avito.ru/saratov/predlozheniya_uslug?q=..." \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
  | grep -oP '"priceDetailed":\{[^}]*"value":\d+' | grep -oP 'value":\d+' | grep -oP '\d+'
```
Rate-limit after 1-2 queries from same IP (429). Batch all queries in one session.

## Yandex.Market price extraction technique

Works from non-Russian IP (200 OK):
```bash
curl -s -L "https://market.yandex.ru/search?text=..." \
  -H "User-Agent: Mozilla/5.0" \
  | grep -oP '"price":\{"value":\d+' | sed 's/"price":{"value"://'
```
Also extract product titles to confirm: `grep -oP '"title":"[^"]*PRODUCT[^"]*"'`

## Material consumption rates (for bag-to-m2 conversion)

| Material | Rate | Source |
|----------|------|--------|
| Bergauf Easy Boden (на 10мм) | 15 кг/м2 = 0.75 мешка/м2 | Manufacturer spec |
| Knauf Rotband (на 10мм) | 8.5 кг/м2 = 0.28 мешка/м2 | Manufacturer spec |
| Dulux Bindo 7 (2 слоя) | 0.16-0.20 л/м2 | Techn. sheet |
| Ceresit CM14 (плитка) | 3-5 кг/м2 | Manufacturer spec |

## EGGER Russia (egger-russia.ru)

No retail pricing. For decor code verification only:
- H1145 = Дуб Бардолино натуральный
- ST10 = Шероховатые глубокие поры
- Manufacturer of LDSP (chipboard), NOT finished doors

## Key insight: EGGER H1145 ST10 is NOT a door model

It is a **decorative laminate pattern code** used on LDSP (laminated chipboard).
The door in the estimate is from an unnamed factory that uses EGGER laminate.

## Notes on data quality

1. Stroylandiya slider data shows RANGE of results, not individual prices
2. data-min == data-max = exact single price for that product
3. Prices are retail. Commercial/juridical pricing may be 15-30% higher
4. Prices as of 23.07.2026. Estimate from ~05.2026 — ~3 month gap (~2-5% inflation)
5. Avito prices are for individual tradesmen, not companies with warranty
6. Yandex.Market prices include marketplace markups
