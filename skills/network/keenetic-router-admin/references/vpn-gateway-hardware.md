# VPN-гейтвей для дома: оборудование и цены (кейс 08.2026)

Цель кейса: весь домашний трафик через VLESS+Reality (vdska) на скорости выше
потолка Keenetic KN-1713 (15-25 Мбит/с на WG/AWG, MT7621 880 МГц).

## Вариант A: OpenWrt-роутер на MT7981 (Filogic 820) — 300-500 Мбит/с

- **Xiaomi Mi Router AX3000T** — 4 799 ₽, DNS (проверено 08.08.2026,
  dns-shop.ru/product/1c0153a5ecd0d582/). Чип Filogic 820 подтверждён DNS.
  ОЗУ 128 МБ — sing-box влезает впритык. OpenWrt: openwrt.org/toh/xiaomi/ax3000t.
- **Cudy WR3000S v1** — цена НЕ подтверждена (страница DNS есть:
  dns-shop.ru/product/bb8808b59cdbd582/, цена за JS). Исторический ориентир
  Pepper 2026: 2 951-3 699 ₽ — НЕ текущая цена. OpenWrt: openwrt.org/toh/cudy/wr3000s_v1.
- **GL.iNet GL-MT3000 (Beryl AX)** — 17 300 ₽, proaim.ru (проверено 08.08.2026,
  itemprop). 512 МБ ОЗУ, порт 2.5G, стоковый OpenWrt-форк от вендора.
  Переплата за бренд/мобильность.

## Вариант B: N100 mini-PC перед Keenetic (WAN → mini-PC → Keenetic-AP)

- **Trigkey G4 N100 16/512** — от 23 000 ₽, trigkey.ru (проверено 08.08.2026;
  itemprop 23000/26500/28500 за конфиги).
- **Beelink Mini S12 Pro N100 16/500** — 50 504 ₽, beelink.ru (офиц. RU-магазин,
  завышает против маркетплейсов; реальная розница ~18-25k — НЕ проверено).
- **GMKtec G3 N100** — цена не проверена (Ozon 403; gmktec.ru = punycode
  xn--h1aagfgn.xn--p1ai, fetch упал на security-approval).
- **Б/у тонкий клиент** (HP T630, Fujitsu Futro S920) — ориентир 2-5 тыс ₽,
  НЕ проверено (Авито блокирует). Критерий: процессор с AES-NI
  (HP T630 = AMD GX-420CA — есть; Intel J1800/J1900 — нет, не брать).
- N100 гонит sing-box ~900+ Мбит/с — запас на годы.

## Метод проверки цен (рецепты, рабочее на 08.2026)

- `ddgs text -q "<модель> цена" -m 8 -r ru-ru -nc` — plain-вывод
  (title/href/body); `-o json` даёт ПУСТОЙ stdout — не использовать.
- DNS: `jina-read <url> --raw | grep -E '[0-9][0-9 ]{2,}₽'` — jina рендерит
  JS; цена товара отдельной строкой, мелкие цены навигации (160-899₽) фильтровать.
- SSR-магазины: `curl -s <url> | grep -oE 'itemprop="price"[^>]*content="([0-9.]+)"'`.
- Матрица доступности сайтов подробнее: e-commerce-pricing/references/price-research-2026-08.md
  (внимание: тот скилл user-owned, файл может не появиться).
