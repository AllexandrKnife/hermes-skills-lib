# Retail Fuel Prices Collection (Russia)

## Source: benzin-price.ru

Crowd-sourced retail fuel prices from actual gas stations across Russia. Works with direct headless browser — no bot protection.

## URL Structure

- Region selection: `https://www.benzin-price.ru/price.php?region=Москва`
- Company filter: append `&company=Роснефть` or `&company=Лукойл`
- Категории: Under "Цены, статистика" → select region → select company

## Data Extraction

The site uses old-school HTML tables (`<table>` elements). To extract price data:

```javascript
// Run in browser console on the page
var tables = document.querySelectorAll('table');
// Find the table with fuel price data (usually table 5)
// Extract rows with format: Date | prices per fuel grade | АЗС address | Source
```

## Price Table Columns

Columns are in this order (spaces indicate no data):
| 80 | 92 | 92+ | 95 | 95+ | 98 | 98+ | 100 | 100+ | ДТ | ДТ+ | Пропан | Метан | СПГ | Эл.ток | АЗС | Источник |

## Known Data Points (Moscow, July 2026)

### Rosneft (largest network, 157+ stations):
| Grade | Price (rub/L) | Notes |
|---|---|---|
| АИ-92 | 64.40 - 65.10 | Most stations at 65.10 |
| АИ-92+ | 65.90 - 66.40 | |
| АИ-95 | 70.50 - 71.30 | Most stations at 71.30 |
| АИ-95+ | 73.00 - 73.85 | |
| АИ-100 | 97.30 - 97.80 | Limited availability |
| ДТ | 79.00 - 80.80 | Varies by location |

### Lukoil (limited data, 8 stations):
| Grade | Price (rub/L) | Notes |
|---|---|---|
| АИ-92+ | 65.27 | |
| АИ-95+ | 74.16 | |
| АИ-100+ | 99.40 | |
| ДТ | 79.28 | |

### Key Observations
- VINK prices are nearly flat (administered, not market-driven)
- Real shortage shows as "нет" (no fuel) on specific grades at specific stations
- Independent stations may have different pricing (minimal data available)
- Data is crowdsourced — not all stations report daily
