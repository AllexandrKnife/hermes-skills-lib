# Russian Retail Sites — Access Patterns

## Stroylandiya (stroylandiya.ru)

**Status**: Works partially from abroad. JS-rendered catalog but price slider data is in raw HTML.

**Получение цен через слайдер**:
curl -s -L "https://stroylandiya.ru/search/?q=..." with Yandex Browser UA
Search output for: data-min="X" data-max="Y" — when min=max, it's the exact price.

**Проверенные запросы**:
- наливной пол Bergauf Easy Boden — 626 руб (1 товар)
- Grohe смеситель для раковины — 1 028-18 860 руб
- ПВХ плитка — разные диапазоны
- стяжка цпс — 110-2 394 руб
- раковина накладная 50 — 2 425-20 960 руб
- порожек алюминиевый — 219-2 047 руб (201 товар)
- грунтовка пола — 181-1 675 руб (7 товаров)

## Avito (avito.ru)

First search works, then IP rate-limited. Batch critical queries into first call.
Саратов: avito.ru/saratov/predlozheniya_uslug/...

## Lemana Pro (saratov.lemanapro.ru)

Qrator-protected from abroad. Works from Russian IPs. Direct product page URLs work if known.

## Egger Russia (egger-russia.ru)

Catalog only, no retail prices. H1145 ST10 = decor code "Дуб Бардолино натуральный", not a product.

## Blocked from abroad
lemanapro.ru (Qrator), petrovich.ru, vseinstrumenti.ru, market.yandex.ru (403)

## User-Agent strategy
Stroylandiya/Avito: Yandex Browser UA + Accept-Language: ru-RU,ru;q=0.9
