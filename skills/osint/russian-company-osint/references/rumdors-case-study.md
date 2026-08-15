# Case Study: ООО «РУМДОРС» (Room Doors)

Company investigated at user request — a door manufacturer listed in construction estimates for a ВымпелКом ЦПК renovation in Saratov.

## Initial Data Provided by User

| Field | Value |
|-------|-------|
| Company name | ООО «РУМДОРС» (Room Doors) |
| Legal address | Чувашская Республика, г. Чебоксары, ул. Ленинского Комсомола, д.27, помещение 6 |
| Production base | Чувашская Республика, г. Новочебоксарск, ул. Промышленная 75П/3 |
| Phone | +7 (8352) 38-75-00 |
| Email | info@roomdoors.site |
| Brand | RD Urban (Новочебоксарск, roomdoors.site) |

## Sources Used in This Investigation

| Source | What It Provided | Method |
|--------|------------------|--------|
| egrul.nalog.ru | ОГРН, ИНН, КПП, dates, director, учредители | curl POST/GET (API) |
| zachestnyibiznes.ru | Full profile, financials, liquidation reason, director ИНН | Browser |
| egrul.nalog.ru (person search) | Director's other entities (ИП) | curl POST/GET by person ИНН |
| roomdoors.site | Contact info, catalog, operational status | Browser + curl |
| whois/ipwhois | Hosting provider (REG.RU), IP geolocation | curl |

## ЕГРЮЛ Search Results

### Entity 1: Чувашская Республика (primary — matches user's address)

| Параметр | Значение |
|----------|----------|
| ИНН | 2130230908 |
| ОГРН | 1222100001815 |
| Дата регистрации | 16.03.2022 |
| **Дата ликвидации** | **16.01.2024** |
| Причина ликвидации | Исключение из ЕГРЮЛ (ст.21.3 ФЗ-129) — недостоверные сведения |
| Директор | Рахматуллин Ирек Небиуллович (ИНН 212408545863) |
| Учредитель | Рахматуллин Ирек Небиуллович — 100% (10 000 руб) |
| ОКВЭД | 16.23 — Производство прочих деревянных строительных конструкций |
| Доходы | ~4.3 млн руб |
| Сотрудников | 5 |

### Entity 2: Ульяновская область (predecessor)

| Параметр | Значение |
|----------|----------|
| ИНН | 7328094394 |
| ОГРН | 1177325012600 |
| Дата регистрации | 29.06.2017 |
| **Дата ликвидации** | **06.12.2023** |
| Причина ликвидации | Добровольная ликвидация по решению учредителей |
| Ликвидатор | Ганиев Марсель Ильдарович (ИНН 732813986663) |
| Учредитель | Лебедев Сергей Алексеевич (ИНН 732809376680) — 100% |
| ОКВЭД | 16.23.1 — Производство деревянных строительных конструкций |
| Доходы | ~12.4 млн руб за 6 лет |
| Сотрудников | 1 |

### Director's Other Entities (Рахматуллин И.Н.)

- **ИП действующее**: ОГРНИП 323210000066418 от 16.11.2023 (registered 2 months after ООО was created, still active)
- **ИП прекращено**: ОГРНИП 311212407000040 от 11.03.2011, закрыто 26.09.2018

## Website Information (roomdoors.site)

| Параметр | Значение |
|----------|----------|
| IP | 31.31.198.99 |
| Хостинг | REG.RU (AS197695) |
| CMS | Joomla 4 + JoomShopping + T4 framework |
| Шаблон | RD (кастомный) |
| Почта | mx1.hosting.reg.ru / mx2.hosting.reg.ru |
| Контакты | 8 800 100-43-02, info@roomdoors.site, sales@roomdoors.site |
| Статус | **Работает** — принимает заявки через форму обратной связи |
| Каталог | Щитовые двери, царговые двери, скрытые двери, перегородки, стеновые панели, декоративные рейки, погонаж |

## Key Findings

1. Both ООО «РУМДОРС» entities (Чувашия and Ульяновск) are **liquidated**
2. The Чувашская entity was liquidated via **ст.21.3** (недостоверные сведения) — a red flag
3. The website **continues to operate** despite liquidation, creating legal risk for contracts
4. The director (Рахматуллин) has an **active ИП** — possible continuing operations under individual entrepreneur status
5. Timeline: Ульяновская entity (2017→2023) followed by Чувашская (2022→2024) — possible region migration pattern

## Risk Assessment

| Risk | Rating | Note |
|------|--------|------|
| Legal entity exists | CRITICAL | Both entities liquidated |
| Website operational | MEDIUM | Still taking orders |
| Director has active ИП | LOW-MEDIUM | Could be operating legally as ИП |
| Product delivery possible | LOW | Production may continue at same facility |
| Invoice/counterparty validity | CRITICAL | Cannot use ООО реквизиты after liquidation |
