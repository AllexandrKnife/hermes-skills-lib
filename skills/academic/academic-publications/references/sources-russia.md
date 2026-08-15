# Российские научные источники: проверенные рецепты (15.08.2026)

Статусы проверены на кейсе Устинова А.Э. (КФУ, экономика).

## elibrary.ru (РИНЦ) — ЗАБЛОКИРОВАН
- Всё отдаёт 403 (author_search.asp — 404-заглушка, author_items.asp — 403),
  даже с cookies после захода на главную.
- Не тратить время; полный список РИНЦ недоступен без авторизации —
  честно помечать «список неполон относительно РИНЦ».

## Google Scholar — РАБОТАЕТ через curl
```
curl -sL -A "Mozilla/5.0 ... Chrome/126.0" "https://scholar.google.com/scholar?q=..." -o /tmp/scholar.html
```
- Статьи: `<h3 class="gs_rt">`, авторы: `<div class="gs_a">`.
- Профили: ссылки `citations?user=XXXX` — владелец в `<div id="gsc_prf_in">`.
- ВАЖНО: профиль автора может не существовать (у Устинова не было),
  профили соавторов — есть. Не путать владельцев.

## cyberleninka.ru — PDF работает
- PDF статьи: `https://cyberleninka.ru/article/n/<slug>.pdf` (прямой GET, 200).
- Авторы: блок «ОБ АВТОРАХ» + «ЦИТИРОВАТЬ СТАТЬЮ» (полная библиография
  с DOI/страницами).
- Поиск по автору: JS-рендеринг, web_extract не берёт — искать через
  Scholar или по цитированиям в других статьях.

## 1economic.ru (издательство «Креативная экономика») — РАБОТАЕТ с Referer
- URL статьи: `https://1economic.ru/lib/<ID>`; ID = последняя часть DOI
  (10.18334/ce.15.12.113856 -> lib/113856).
- Скачивание PDF: на странице статьи искать `href="/lib/<ID>/?download=<TOKEN>"`,
  затем `curl -e "https://1economic.ru/lib/<ID>" ".../?download=<TOKEN>" -o file.pdf`
  (БЕЗ Referer возвращает HTML-заглушку, не PDF; оба токена дают один PDF).
- Это источник для: Креативная экономика, Вопросы инновационной экономики,
  Экономические отношения, Управление финансовыми рисками, Российское
  предпринимательство.

## rppe.ru (OJS, «Региональные проблемы преобразования экономики») — РАБОТАЕТ
- Страница: `article/view/<ID>`; PDF: `article/download/<ID>/<galley_id>`
  (galley_id из HTML страницы: grep 'article/download').
- Библиография: meta-теги `citation_author`, `citation_title`,
  `citation_date`, `citation_issue`, `citation_firstpage`, `citation_doi`
  — парсить их, не текст.

## eehacrt.ru («Электронный экономический вестник Татарстана») — РАБОТАЕТ
- Архив: `https://eehacrt.ru/readers/arhiv-vypuskov/` — HTML содержит
  ссылки на PDF выпусков: `wp-content/uploads/<...>/<год>_<№>.pdf`.
- Статья в выпуске: извлекать страницы по колонтитулу
  («...№2 (апрель-июнь) 2020 года 23» = журнальная стр. 23);
  журнальная нумерация ≠ PDF-страницы (сдвиг на титульные листы).
- Пример: стр. 23-28 журнала = PDF-страницы 22-27 (0-based).

## World Bank API — РАБОТАЕТ (бесплатно, без ключа)
```
https://api.worldbank.org/v2/country/{C}/indicator/{I}?format=json&date=2000:2022&per_page=100
```
- Индикаторы: NY.GDP.MKTP.KD.ZG (рост ВВП), NE.GDI.FTOT.ZS (инвестиции),
  NE.TRD.GNFS.ZS (торговля), FP.CPI.TOTL.ZG (инфляция),
  SL.UEM.TOTL.ZS (безработица), NY.GDP.MKTP.KD (ВВП пост. долл.).
- Таймауты на сериях запросов: timeout 60, retry 4, пауза 0.5с.

## MOEX ISS — РАБОТАЕТ (бесплатно, капитализация!)
- Капитализация по тикеру (важно: это и есть цена x акции):
```
https://iss.moex.com/iss/engines/stock/markets/shares/boards/TQBR/securities/PIKK.json?iss.meta=off&iss.only=marketdata&marketdata.columns=SECID,LAST,ISSUECAPITALIZATION
```
- Поле ISSUECAPITALIZATION = рыночная капитализация в рублях.
- /iss/securities/PIKK.json — только description/boards, ISSUECAPITALIZATION там НЕТ.

## Бесплатная замена СПАРК (ТРИЗ: приёмы 25/26/3/13/24)
- Капитализация: MOEX ISS (проверен, живой).
- Бухотчётность: БФО ФНС bo.nalog.gov.ru (интерфейс; API требует сессии —
  GET /nbo/organizations/search?query=... не сработал напрямую, POST — 405).
- Реквизиты: egrul.nalog.ru. Макро/отраслевые: Росстат ЕМИСС fedstat.ru.
- Кредиты/ипотека: cbr.ru. Недвижимость: ДОМ.РФ.
- Yahoo Finance: 401 (Invalid Crumb) — не использовать.

## ORCID
- API поиск по имени (given-names+family-name) часто возвращает пусто —
  полный ORCID брать из текстов статей (блок «Об авторах», e.g.
  «ORCID: 0000-0003-3529-7273»).

## Поиск AuthorID/SPIN соавторов
- Страницы преподавателей вузов (kgasu.ru/universitet/person/...) содержат
  elibrary AuthorID и списки «Авторы/другие» — по ним находить совместные
  статьи и проверять состав авторов.
