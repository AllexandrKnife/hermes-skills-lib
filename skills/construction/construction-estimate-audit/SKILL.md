---
name: construction-estimate-audit
version: 1.0.0
description: "Use when Audit construction estimates for overpricing"
critic_status: done
license: Proprietary
platforms: [linux, macos, windows]
---

# Construction Estimate Analysis (сметный анализ)

## When to use

Use this skill when asked to review a construction estimate/smeta for overpricing, fraud indicators, or cost optimization. The user is from служба экономической безопасности (economic security department). Typical triggers: "проверь смету", "найди признаки фрода", "проанализируй смету на завышение".

## User profile

- Russian-speaking, technical colleague
- Needs direct answers, no disclaimers
- Reports go to management — need proper structure, source references, and numbered conclusions
- Work output: .docx (detailed analysis) + .pptx (presentation for meeting) + .docx (strategy) + .docx (economics)

## Workflow

### Step 1. Arithmetic verification

Before doing anything else, verify:
- Line-by-line multiplication (volume × unit price)
- Column totals
- НДС calculation (confirm current rate — in 2026 РФ НДС is 22%, NOT 20%)
- Grand total

Report any discrepancies immediately.

### Step 2. Identify overpricing items

For each line item:
- Check if the unit price is realistic for the **region** (not Moscow prices for regional projects)
- Check if the volume/quantity makes physical sense (e.g. waste volume from floor area)
- Check if the same work appears twice (double billing)
- Check if materials are priced at premium while brand is mid-range
- Check for "с сохранением" items that then appear as new material purchases

### Step 2b. Systematic pattern detection (multi-contract)

When the user reveals multiple contracts for the same project with the same contractor:
1. **Request ALL contracts upfront** — the user may mention casually ("есть еще один договор"). Ask explicitly.
2. **Cross-reference identical line items** — same prices across contracts = systematic overpricing. ALSO check for DIFFERENT prices on the same item across contracts — that signals inconsistent pricing:
   - ПВХ-плитка работа: 1,100 руб/м² in both = pattern, not coincidence
   - Grohe смеситель: 6,475-6,475.50 in both = identical material pricing
   - Dulux Bindo 7 работа: 500 руб/м² in both = pattern
   - Вывоз мусора: 60 м³ in both for DIFFERENT demolition volumes = шаблон
   - EGGER door: 33,650 in contract A, 26,918 in contract B = разная цена на одинаковый товар → завышение в одном из договоров на 6 732 руб/шт
3. **Combine totals** for leverage — 3.5M + 4.1M = 7.6M total. One overpriced estimate = error. Two identical ones = system
4. **Combine просрочка periods** — 40 + 25 days = stronger overall delay signal
5. **Present as SYSTEMATIC FRAUD** in negotiations, not isolated errors

### Step 2c. SC W-1 (Специальные условия подряда) — penalty & leverage extraction

**Critical:** When the user mentions or provides Специальные условия подряда (SC W-1), extract ALL financial claims. This document contains the REAL penalty clauses.

**Step 2c(i): SC W-1 п. 8.1 — Неустойка за просрочку работ**

This is the MOST IMPORTANT clause. Graduated penalty:

| Period | Rate | Applies when |
|--------|------|-------------|
| < 14 days | 0.2% per day | Short delays |
| 14-30 days | 0.3% per day | Moderate delays |
| > 30 days | 0.4% per day | Long delays (common) |

Rate applies to the **entire period** from day 1, not progressively (e.g. 40 days = 0.4% flat for all 40 days).

Formula: **работы (не материалы) × ставка × дни просрочки**

Always base the penalty on the WORK column only (цена работ), not materials.

**Step 2c(ii): Other SC W-1 claims**

| Clause | What | When applicable |
|--------|------|----------------|
| п. 8.2 | 0.1%/day for late closing docs | After work is complete AND docs are overdue. **NOT applicable if work is still in progress** |
| п. 8.3 | 0.1%/day for defect correction delay | After an акт о недостатках is signed and correction deadline missed |
| п. 8.4 | 50 000 RUB per subcontractor | If subcontractors were hired without written consent |
| п. 8.6 | 300 000 RUB per alcohol/drug incident | Only with photo/video evidence |
| п. 8.7 | 10 000 RUB per worker | If workers entered without prior notification (ФИО, passport data) |
| п. 8.8 | 0.1%/day for late money return | After advance return is due and not paid |
| п. 8.9 | Full damages on top of penalty | Penalty is штрафная (punitive) — damages are separate. Documented losses: difference with new contractor, expert fees, administrative fines, lost rental income, legal costs |
| п. 7.5 | Соразмерное уменьшение цены | **CRITICAL: applies to QUALITY DEFECTS only, NOT general overpricing.** Requires an акт о недостатках. If materials don't match specification (EGGER ≠ nameless door) — this applies. If prices are simply above market — use different basis |
| п. 2.4 договора | Избыточные объёмы (main contract, not SC) | **For OVERPRICING of volumes (not defects):** «Если окажется, что выполнение части Работ не требуется и стоимость должна быть уменьшена, то новая цена указывается в КС-2 и Финальном акте» |
| ст. 1102 ГК РФ | Неосновательное обогащение | **For inflated unit prices (not defects, not volumes):** Contractor would receive unjust enrichment if paid above market. Requires proof of market price — use Stroylandiya/Avito data |
| п. 9.1.2 | Unilateral termination for deadline violation | Use as threat leverage in negotiations |
| п. 9.1.3 | Termination if materials ≠ specification | EGGER H1145 ST10 = decor code for laminate surface, not a door model. If the door's actual manufacturer differs from what was specified — materials don't match |
| п. 9.4.2 | On termination by fault — don't pay for incomplete work + return advance in 10 days | Maximum leverage scenario |
| п. 6.6 | Expert evaluation costs on loser | If quality dispute → expert costs on contractor |

**Critical distinction:** п. 7.5 (соразмерное уменьшение) applies to QUALITY DEFECTS only. Overpricing (higher than market prices) is NOT a defect. Overpricing is handled by:
- **п. 2.4 договора**: if work wasn't needed in stated volume (e.g. waste 60m³ ≠ actual 25m³)
- **ст. 1102 ГК РФ**: неосновательное обогащение for inflated unit prices
- **ст. 723 ГК РФ**: if work quality is affected by cost cutting

**Step 2d. General Conditions (Общие условия) extraction**

When a contract references GC/SC documents hosted on the customer's website, download and scan them:
- **П. 336 GC**: одностороннее расторжение + возмещение убытков (if present)
- **П. 443 GC**: неустойки штрафные + полное возмещение убытков
- **П. 460 GC**: 0,1% в день за просрочку возврата аванса
- **П. 437 GC**: дополнительная ответственность в Специальных условиях (SC) — need to check those too
- **Contract > Приложения > SC > GC** priority order — the main contract terms override GC/SC
- If no penalty clause exists for contractor delay (typical): only ст. 395 ГК РФ + убытки + отказ применимы

### Step 2d. Two-response reconciliation

When you get responses from TWO different people on the same questions:

| Signal | Action |
|--------|--------|
| Engineering says "X", senior says "not X" | Create a cross-reference table. Resolve by authority: senior > engineer for policy, engineer > senior for site facts |
| Same question, opposite answers | Flag as discrepancy. Ask user to clarify. In the meantime, use the LESS favorable answer for your position (conservative approach) |

Common cross-references to check:
- "Подрядчик предупреждал о просрочке?" — engineer says "нет", senior says "устно предупреждал". Senior may have had calls the engineer didn't know about.
- "Сертификаты предоставлены?" — senior says "во вложении", engineer says "нам нет". Different people, different access levels.
- "Оплата проведена?" — engineer says "думаю нет", senior says "не проводилась". Senior has authority over financial info.

**CRITICAL: Do NOT ask payment-sensitive questions by email if the internal recipient may be compromised.** When engineer tentatively says "думаю, ещё не перечисляли" — verify through an INDEPENDENT channel (direct call to finance, not through the intermediary). The engineer may be told to respond this way.

**After reconciliation: update the strategy IMMEDIATELY.** Each new fact changes the recommended variant ranking.

### Step 2e. OSINT on suppliers and manufacturers — company verification

When the estimate references a specific brand or manufacturer (e.g. "EGGER H1145 ST10"), and especially when photos or passports of products become available:

**Verify manufacturer existence**

1. **Get the ИНН/ОГРН** — from the product passport, certificate, or declarations. Search the company by name.
2. **Check ЕГРЮЛ status** — via nalog.ru or open data. Key flags:
   - Ликвидировано — company ceased to exist
   - Исключено за недостоверные сведения — most severe
3. **Cross-check dates:**
   - If company was liquidated BEFORE the contract/installation date → goods may be counterfeit
   - If company was liquidated BEFORE the passport/manufacturing date → **critical violation** (документы на несуществующее юрлицо)
4. **Legal implications:** No valid certificate, no warranty recourse, potential ст. 327 УК РФ (подделка документов).
5. **Negotiation script:** «Эта компания ликвидирована [дата], за [X] до договора. Кто реальный производитель? Где сертификаты? Кто отвечает по гарантии? Это нарушение п. 9.1.3 SC W-1 + п. 5.2 SC W-1.»

**Reference file:** `references/osint-company-verification.md`

### Step 2f. Field feedback loop (after Step 2, before market pricing)

Send the site engineer (куратор работ) a structured list of questions. Split into two channels:

**By email (11 questions):**
- Financial: which КС-2/КС-3 signed, how much paid, certificates received (п. 1.3.5 ТЗ)
- Materials: brand/model from packaging — doors (manufacturer label), tiles, glue, cable channel profile (100×50 vs 105×50), stone type for countertop
- Documentation: work log (журнал работ), start date, last worker presence, delay notifications
- Responsible person: was one assigned? (п. 1.2.6 ТЗ)

**In-person / site visit (16 questions):**
- Physical measurements: actual m² of each work type (screed, tiles, painting)
- Photograph markings: door edge label (manufacturer), mixer model under sink, sink article number
- Visual quality check: cracks in screed, paint coverage, tile gaps
- Strategic: which work is quality, which has defects, how long for a new contractor to finish

**CRITICAL: Iterative re-calculation after EVERY batch of engineer/site responses.**

The engineer's answers are NOT just informational — they directly change the estimate numbers and the strategy. Each answer requires immediate action:

1. Start with the original estimate total
2. For each answer, check if it affects the estimate:
   - "Стяжку не заливали" → deduct full line item cost IMMEDIATELY (~531k RUB)
   - "Акты не подписаны" → 100% leverage, payments are not due
   - "Деньги не перечислены" → full financial leverage
   - "Двери заказные" → adjust door price evaluation upward
3. After each batch, re-run the three-scenario economic calculation
4. Adjust and RE-RANK the strategic variants (мирный/переговорный/жёсткий):
   - стяжка не сделана + акты не подписаны + деньги не перечислены → "мирный" вариант becomes OBSOLETE
   - Same facts → "переговорный" becomes primary recommendation
   - Same facts + SC W-1 п.8.1 penalty confirmed → position becomes максимальная
5. Update the strategy document with new numbers and re-ranked variants
6. Do NOT update only the numbers — update the STRATEGIC RECOMMENDATION too

**Example from one session:**
- Engineer: "Стяжку не заливали, только наливной пол"
- → Screed line item (531,200 RUB) immediately deducted from estimate
- → Total realizable price changed from ~3.48M to ~2.95M (without screed)
- → "Мирный" вариант declared obsolete
- → "Переговорный" вариант became the primary recommendation
- → "Жёсткий" вариант remained as backup

**Do NOT update only the numbers.** If the engineer reveals that акты не подписаны and деньги не перечислены — the balance of power shifts completely in favor of the customer, and all three strategic options need re-ranking.

### Step 3. Collect market price data — persistence strategy

Sources to reference (user expects source links in the document):
- **Work prices:** Avito.ru (avito.ru/saratov — Услуги / Ремонт, Саратов). Извлечение цен из JSON: grep -oP '\"priceDetailed\":\\{[^}]*\"value\":\\d+' (первые 1-2 запроса работают, затем rate-limit 429).
- **Material prices:** Лемана ПРО (lemanapro.ru) — ❌ Qrator. Петрович (petrovich.ru) — ❌ QRator. Стройландия (stroylandiya.ru) — ✅ работает (data-min/data-max). ВсеИнструменты (vseinstrumenti.ru) — ❌ captcha.
- **Comparison:** Яндекс.Маркет (market.yandex.ru) — ✅ работает (проверено 07.2026: 200; статус нестабилен — в отдельных проверках 403). Извлечение: grep -oP '\"price\":\\{\"value\":\\d+'.
- **Official pricing:** ФГИС ЦС (fgiscs.minstroyrf.ru) — state construction pricing system
- **Regional standards:** ТЕР (территориальные единичные расценки) for the specific region
- **Manufacturer sites:** EGGER Russia (egger-russia.ru) — manufacturer catalog only, shows decorative patterns — no retail pricing

NOTE: Russian retail site access from non-Russian IPs — documented behavior (see `references/russian-retail-site-access.md`):
- ✅ Стройландия (stroylandiya.ru) — works, confirmed material prices found (Bergauf Easy Boden 617 руб/25кг, смеси 306-377 руб/25кг). NOTE: saratov.stroylandiya.ru subdomain returns 503 since ~July 2026 — use main domain
- ⚠️ Авито (avito.ru) — first request works, then rate-limits
- ❌ Лемана ПРО (lemanapro.ru) — "Отключите VPN" block
- ✅ Яндекс.Маркет (market.yandex.ru) — ✅ Works (200) with JSON price data — `grep -oP '"price":\{"value":\d+'` extracts prices
- ❌ Петрович (petrovich.ru) — QRator bot protection
- ❌ ВсеИнструменты (vseinstrumenti.ru) — captcha challenge

**Persistence protocol when blocked:**
1. First attempt — try all known working sites (Stroylandiya first)
2. When blocked — document exactly which sites blocked and how
3. **Do not give up** — try alternative sites, different subdomains (main site vs regional), different user agents (Yandex Browser UA sometimes works when Chrome UA doesn't), different search queries
4. Use the price slider technique: Stroylandiya exposes data-min/data-max attributes in HTML even when JS-rendered content is missing. Search for a product, then regex: `re.findall(r'data-min="(\\d+)" data-max="(\\d+)"', data)`
5. If still blocked — ask user for specific working URLs from their Russian IP. Include a precise list: what pages you need, what prices you're looking for
6. If user provides URLs — immediately extract the prices and add clickable hyperlinks to the document
7. **CRITICAL** — if the user says "ты сдался, борись" or equivalent, DO NOT back down. The user expects persistence and it is a DIRECT ORDER to fight harder. Immediately respond with a detailed evidence report of every attempt.
8. **Evidence report format when blocked:** Present a table of ALL sites tried with status codes, what was returned, and what changed between attempts. Show the ONE thing that partially worked (e.g. Stroylandiya price sliders). Extract what data you COULD get. Then ask for specific URLs with a concrete table of what you need.
9. **When user provides an URL:** Extract prices immediately, add clickable hyperlinks, then iterate — ask for 1-2 more pages.
10. **Key finding:** EGGER H1145 ST10 is a **decor/laminate code** for surface finish, not a door model. EGGER produces laminate surfaces (HPL/CPL/melamine) used by door factories. A door with EGGER laminate finish is a legitimate product. The real question: who manufactured the door core? Request manufacturer labels from the engineer. A no-name door with EGGER finish ≠ a branded door premium.
11. **Use Python subprocess.run with curl for sites that require custom headers.** Switch between Chrome/Yandex Browser/Android user agents. Try main domain vs regional subdomain vs mobile subdomain vs search page vs product page vs API endpoint.
12. **JSON price extraction from HTML pages** — when curl returns raw HTML with embedded JSON, extract prices directly:
    - **Avito**: `grep -oP '"priceDetailed":\{[^}]*"value":\d+' | grep -oP 'value":\d+'` — extracts ruble values cleanly
    - **Yandex.Market**: `grep -oP '"price":\{"value":\d+'` — extracts prices (may need division by 100 for some listings)
    - Always verify by also extracting product titles to confirm you got the right item

### Step 4. Build comparison table

For each overpriced item, create a table with:
| Parameter | Estimate | Market (Region) | Difference |

Include a "Source" column or footnote referencing how the market price was obtained.

### Step 5. Calculate economic effect — three scenarios

- **MIN** (~50% of overpricing conceded): partial renegotiation
- **REALISTIC** (full overpricing adjustment): соразмерное уменьшение по ст. 723 ГК РФ
- **MAX** (full adjustment + 10% holdback + interest): legal escalation

Label all three clearly. Express as both rubles and % of original estimate.

### Step 6. Legal framework

Include references:
- **п. 2.4 договора** — уменьшение цены при избыточных объёмах
- **Ст. 723 ГК РФ** — соразмерное уменьшение цены (при дефектах)
- **Ст. 715 ГК РФ** — отказ от договора при просрочке
- **Ст. 395 ГК РФ** — проценты за пользование чужими средствами
- **Ст. 1102 ГК РФ** — неосновательное обогащение (завышенные цены)
- **Ст. 159 УК РФ** — мошенничество (только при системном завышении >30% И доказанном умысле/ущербе; формулировки строго условные — «возможна квалификация», не «совершил»)
- **Ст. 327 УК РФ** — подделка документов (паспорт на несуществующее юрлицо)
- **Ст. 14.7 КоАП РФ** — обман потребителей (ТОЛЬКО при потребительском характере отношений; в B2B не применима — вместо неё ст. 431.2 ГК, ст. 15/393 ГК)
- **Ст. 14.45 КоАП РФ** — отсутствие сертификата на продукцию
- **Ст. 431.2 ГК РФ** — недостоверные заверения (штраф 10% — если предусмотрен договором)

### Step 7. Generate deliverables

**Primary deliverable (always create first):** `Executive_Summary_*.docx` — 2-3 page one-pager for руководитель. Must fit on 2-3 A4. Structure:
   - **Заголовок:** крупные цифры (бюджет, завышение %, целевая цена, экономия). По центру, жирно.
   - **Блок 1 — СУТЬ:** 3-4 факта, не требующих экспертизы.
   - **Блок 2 — ДВА ДОГОВОРА:** сводная таблица (красное = завышение, зелёное = цель).
   - **Блок 3 — УЧАСТНИКИ:** таблица + предупреждение лояльности.
   - **Блок 4 — ПРИЗНАКИ СИСТЕМНОСТИ:** cross-сметная таблица совпадений.
   - **Блок 5 — РЫЧАГИ:** договорные и финансовые.
   - **Блок 6 — ПЛАН ДЕЙСТВИЙ:** таблица (действие, срок, ответственный).
   - **Блок 7 — РЕШЕНИЕ:** пункты на утверждение + поля подписей.

**For multi-contract projects:** Executive Summary is the main document. Detailed analyses become references/appendixes. Руководитель reads 2 pages, СЭБ reads the appendix. This replaces the need for 3+ separate files.

### Step 8. Self-check with document-critic (mandatory)

After completing ALL deliverables, before showing the user:

1. **Load the `document-critic` skill** and apply layers 1-3 (arithmetic, sources, contradictions) at minimum. Apply layers 4-8 if time permits or the document goes to руководство.

2. **Fix ALL findings in ONE batch** — do not leave anything for "next iteration". Users explicitly reject incremental fixes. Collect all findings, fix them all, regenerate the document.

3. **Re-verify** — run document-critic again on the fixed version. If new findings appear, fix those too. Max 3 iterations. If the 3rd iteration still has issues, the methodology needs rework.

4. **Verify these specific checks:**
   - Risk criteria stated explicitly before comparison table
   - Specific URLs (not just domain names)
   - Economic contradictions resolved (if two numbers differ, explain why)
   - Criminal law articles use CONDITIONAL language only — never assert as fact without evidence
   - Recommendations include сроки and ответственные
   - Сметные завышения and неустойка are in separate rows

### Step 9. Create supplementary deliverables

1. `Анализ_сметы_*.docx` — detailed analysis with methodology, source references, tables
2. `Презентация_встреча_*.pptx` — 8-12 slides for negotiation meeting (Beeline style if applicable)
3. `Стратегия_*.docx` — step-by-step negotiation strategy + document templates
4. `Экономический_эффект_*.docx` — three-scenario cost-benefit calculation
5. `План_действий_ЭБ_*.docx` — action plan for economic security department (who does what, when, legal basis)

### Step 10. Stakeholder objection handling (возражения смежников)

When an internal stakeholder (куратор, руководитель проекта, коллега из смежного отдела) pushes back on the analysis with objections like «на каком основании», «чем вас не устраивает», «в смете не указан конкретный производитель»:

**Response protocol — always in this order:**

1. **Cite the specific contract clause first** — not general principles, not philosophy. One clause is enough if it's directly on point.
   - Документы на материалы → п. 1.3.5 ТЗ + абз. 5 (право отказаться от приёмки)
   - Сертификаты → п. 5.3 SC W-1 (срок 10 дней с момента запроса)
   - Гарантия → п. 3.1 договора (12 месяцев)
   - Несоответствие материалов → п. 9.1.3 SC W-1 (отказ от договора)

2. **Explain WHY in one sentence** — don't write an essay. The stakeholder needs ammunition, not education.
   - «Производитель ликвидирован — гарантия не обеспечена, предъявить претензию некому»
   - «Паспорт выдан после ликвидации — легальность происхождения под вопросом»
   - «Без накладных не можем проверить цену и цепочку поставки»

3. **End with the requested action** — «прошу направить запрос через ЭДО», «шаблон в файле Запрос_на_двери.docx».

**Common pushbacks and responses:**

| Pushback | Response |
|----------|----------|
| «В смете не указан конкретный производитель» | «С этим и связан запрос — нам нужно установить, кто произвёл двери, чтобы проверить качество и гарантию» |
| «Вот фото паспорта и дверей в упаковке» | «Паспорт выдан после ликвидации производителя. Фото коробок не подтверждают происхождение. Нужны накладные/УПД.» |
| «Двери не требуют обязательной сертификации» | «П. 5.3 SC W-1 требует предоставить документы по запросу независимо от обязательности. И п. 3.1 — гарантия 12 месяцев не обеспечена.» |
| «Вот счёт от посредника — всё легально» | «Проверим ИНН посредника, сравним цену со сметой, установим цепочку. Если производитель дверей — тот же ликвидированный РУМДОРС — вопрос остаётся.» |
| «Почему нужны именно накладные, а не фото?» | «Накладная/УПД — первичный документ, подтверждающий факт приобретения, цену и поставщика. Фото коробок — нет.» |

**

**Document verification workflow (когда прислали счёт/УПД):**

When a stakeholder provides a supporting document (счёт, УПД, договор поставки):

1. **Extract seller details** → Проверить ИНН продавца через nalog.gov.ru
2. **Compare price with estimate** → Если цена материала в смете близка к закупочной — завышение в работе, не в материале
3. **Check manufacturer traceability** → Указан ли производитель в документе? Если да — проверить его статус (ликвидирован/действует). Если нет — цепочка гарантии обрывается.
4. **Cross-check dates** → Дата документа до или после ключевых событий (ликвидация производителя, дата паспорта)
5. **«Не требует сертификации» не аргумент** — п. 5.3 SC W-1 требует предоставить документы в течение 10 дней независимо от того, обязательна сертификация или добровольна

### Document completeness standards — mandatory before delivery

Every .docx MUST pass these checks:

**Risk criteria stated explicitly** before comparison table:
- "КР = завышение >100% ИЛИ сумма >50 000 руб"
- "ВЫС = 50-100% ИЛИ 10 000-50 000 руб"
- "СР = 20-50%. НИЗКИЙ = до 20%"

**Sources include specific URLs** not just domain names:
- stroylandiya.ru/search/?q=Bergauf+Easy+Boden+20 (not just stroylandiya.ru)
- market.yandex.ru/search?text=Royal+Thermo (not just market.yandex.ru)

**Economic contradictions resolved** — if two numbers differ, explain why.

**Recommendations include сроки and ответственные** — every action must state who and when.

**Appendices with ready-to-use templates:**
- **Приложение 1**: Шаблон служебной записки (гриф ДСП, императив)
- **Приложение 2**: Шаблон email-запроса подрядчику

## Document structure (analysis .docx)

1. Методология и источники данных
2. Проверка арифметики
3. Критические завышения (table: item | estimate | market | difference | source | risk)
4. Завышения средней степени
5. Требуют уточнения
6. Сводная ведомость завышений
7. Рекомендации

## Presentation structure (.pptx — Beeline style: white/yellow/black)

Slide layout (11 slides):
1. Title
2. Facts
3. Overpricing overview (summary table)
4. Detailed breakdown of ALL items (3x3 grid)
5. Legal basis
6. Our demands
7. Scenario A — Conflict (dark slide)
8. Scenario B — Deal (two columns: give/get)
9. Economic effect
10. Deal terms
11. Next steps

## Conventions

- **Language:** Russian throughout
- **Tone:** инженер — инженеру, no disclaimers
- **Formatting:** Tables with clear headers, comparison columns, risk labels
- **Risk labels:** КРИТИЧЕСКАЯ / ВЫСОКАЯ / СРЕДНЯЯ / НИЗКАЯ
- **Sources:** Always include a "Методология и источники данных" section. Reference specific platforms in each table.
- **Numbers:** Rubles without VAT for line items, both variants for totals

### 11. Internal stakeholder letter — decision-request format

When asking an internal stakeholder (куратор, Баранов) for decisions, NOT writing an analysis:

**Structure:**
1. Subject: «По итогам анализа по договорам [номера] прошу определить позицию по [N] вопросам»
2. Each question = separate numbered item with:
   - **Sum** (how much — неустойка 697 тыс, завышение 236 тыс)
   - **Brief inline justification** (1-2 lines: «расчёт: стяжка 50 мм × 415 м² = 20,75 м³ + прочий демонтаж ~17 м³»)
   - **Legal basis with PURPOSE stated** («основание для соразмерного уменьшения цены — п. 7.5 SC W-1», not just «основание — п. 7.5»)
   - **Decision question** («взыскиваем/прощаем/частично?», «предъявляем или скидка?»)
3. Urgency marker: «неустойка капает каждый день»
4. For ethics issues — комплаенс query: «Прошу инициировать запрос в комплаенс: насколько корректно с точки зрения деловой этики и комплаенс-политики ПАО «ВымпелКом» принимать работы, по которым предоставлен фиктивный документ?»

**Pitfalls:** only full contract numbers (not «дог.1»); justify each figure inline; state what the legal basis IS FOR; ask for a decision, don't just inform.

### 12. Prevented vs compensated damage — for reporting

| Category | Definition | Examples |
|----------|-----------|----------|
| Prevented (предотвращённый) | Identified before payment — money never left | Undone work caught, template volumes blocked, inflated prices flagged |
| Compensated (возмещённый) | Recovered after payment | Penalty collected, соразмерное уменьшение accepted, advance returned |

If КС-2/КС-3 are unsigned and money not paid → ALL effect = prevented, not compensated.
Formula: Economic effect = Prevented + Compensated.

### 13. Document confirms price → abandon that argument

When contractor provides счёт/УПД подтверждающий сметную цену — STOP arguing the price on that item. The document confirms the procurement cost. Switch to other grounds (quality, warranty, provenance) or drop the claim. Do not continue asserting «цена не обоснована» after documentary proof.

### 14. .txt as intermediate format

For quick coordination — produce formatted .txt (not .docx) with:
- ASCII borders (═, ─, ┌, └)
- Summary table
- Contract clause references
Save in case folder. Convert to .docx later if needed.

## Common pitfalls

- **НДС rate**: In 2026, РФ НДС is 22%. Do NOT assume 20%.
- **EGGER H1145 ST10 is NOT a door model**: It is a **decor/laminate code** (colour + texture). EGGER supplies laminate surfaces to door factories. A door with EGGER laminate finish is a legitimate product. The question is not "is it a door?" but "who manufactured the door core, and does the price match that manufacturer?". Request the manufacturer label from the site engineer. The decor code alone does not justify a premium door price from a no-name factory.
- **Re-brands to track**: Leroy Merlin → **Лемана ПРО** (lemanapro.ru). Do not reference LeroyMerlin.ru.
- **Double грунтовка**: Two грунтовка entries at different stages (under screed + under self-leveling floor) are separate process steps, not double billing.
- **Commercial vs residential pricing**: Commercial work (4th floor, no elevator, logistics) costs more than residential. Factor this into market price estimates.
- **Premium materials**: Verify actual market positioning before calling a brand non-premium.
- **File locking**: Windows locks .docx/.pptx when open in Word. Save to /tmp/ first, then copy. Use _v2 suffix if original path is locked.
- **Word table formatting**: Use proper python-docx `Light Grid Accent 1` tables with blue headers (#002B5C) and alternating row shading (#F0F2F5). NEVER use ASCII-art pipes (|) and dashes (-) — these render as literal text in .docx and are unreadable.
- **Search blocking**: Don't give up when first site blocks. Rotate: different subdomain, different user agent (Yandex Browser), try the price slider regex technique. Document what worked and what didn't for the user.
- **Engineer may not know everything**: They may not have access to financial documents, certificates, or photos. Ask anyway — even partial answers strengthen the analysis.
- **Re-calculate after engineer feedback**: If engineer says a line item wasn't executed (e.g. "стяжку не заливали"), IMMEDIATELY deduct it from the estimate and re-run the total calculation. This is the single highest-value adjustment.
- **Separate email from in-person questions**: Financial/document questions go by email. Physical measurements and photos go on site visit. Don't mix them — the engineer can't measure m² from their desk.
- **10% holdback (п. 2.6.2) is NOT a current lever**: It only applies AFTER payments have started. If no payments have been made, the 10% holdback is not a financial claim — just state that money is not yet due as the actual leverage point.
- **Rigorous citation chain**: When citing contract clauses, always include the FULL chain. Do not just say «п. 8.1 SC W-1». Use: «п. 4.3.7 договора №26114837 (SC W-1 → п. 8.1)». When the same clause applies to multiple contracts, cite BOTH: «п. 4.3.7 договоров №26114837 и №26127673 (SC W-1 → п. 8.1)». The user expects to see which specific document provisions are being cited, with the reference path from the contract down to the specific clause, including the contract number.
- **Writing to potentially compromised recipients**: If the internal recipient (co-worker) may be sympathetic to the contractor, use a FORMAL служебная записка (memo) format with confidentiality mark («Гриф: ДСП»), informational tone (not asking for agreement), and specific blocking instructions («Прошу обеспечить учёт указанных требований при взаимодействии с подрядчиком»). Key markers of formal CYA memo vs collaborative letter:
  - Title: «СЛУЖЕБНАЯ ЗАПИСКА» not «Письмо»
  - Headers: «Кому:» / «От:» with full names
  - Confidentiality mark: «Гриф: ДСП»
  - Opening: «Настоящим уведомляю Вас о необходимости учесть...» not «Прошу рассмотреть...»
  - Blocking instructions for payments: «Не подписывать закрывающие документы до урегулирования»
  - Close: «Прошу подтвердить получение и обеспечить учёт» - this establishes that they were informed in writing
  - This serves as CYA documentation if they act against your written recommendations.
- **Full legal qualification chain for counterfeit documents**: When product passport is issued by a liquidated company, cite ALL levels of liability: Уголовная (ст. 327 ч.1, ч.3; ст. 159 ч.2 УК РФ), Административная (ст. 14.7, 14.45 КоАП), Гражданская (ст. 431.2, 469, 475 ГК РФ). BUT always use CONDITIONAL language — «если подтвердится злонамеренное использование», «возможна квалификация», not «подрядчик совершил преступление».
- **Run document-critic before final delivery**: After completing the analysis, run a document-critic self-check (layers 1-3 minimum). Fix ALL findings in ONE batch, not incrementally. Users explicitly reject incremental fixes.
- **Never state criminal charges as fact** — a liquidated manufacturer + posthumous passport is a RED FLAG, not a crime. Use conditional language: «Если подтвердится злонамеренное использование — возможна квалификация по ст. 327 УК РФ». Check: proof of intent? Proof of damage? Expert opinion? If no to all three — conditional only.\n- **Separate сметные завышения from неустойка** — they are different legal categories. «Общее завышение 2,3 млн» is wrong if it mixes inflated prices (1.0M) with late-penalty (0.5M) and undone work (0.5M). Present each claim in its own row.
- **Пересчёт расхода материалов (цена за мешок ≠ цена за м2)** — when comparing retail prices (rub/мешок, rub/ведро) with estimate column (rub/м2), ALWAYS recalculate through material consumption rate. Bergauf Easy Boden 20кг at 626 руб/меш: 1.5 kg/mm/m2 at 10mm = 15 kg/m2 = 0.75 мешка/m2 = 470 руб/m2, NOT 626 руб/m2. Without recalculation you produce a GROSS ERROR.
- **Separate сметные завышения from неустойка in reporting** — they are different legal categories with different calculations. When the analysis says "total overpricing", it must be the SUM OF сметные завышения only (inflated volumes, inflated unit prices). The неустойка is a SEPARATE claim for просрочка. Mixing them inflates the "overpricing %" figure and confuses the reader. In Executive Summary, present them as separate rows.
- **NEVER state criminal charges as fact without evidence** — a liquidated manufacturer + posthumous passport is a RED FLAG, not a crime. Use conditional language: "Если подтвердится злонамеренное использование документов ликвидированного юрлица — возможна квалификация по ст. 327 УК РФ". Run a quick evidence check before citing any УК РФ article: do we have proof of intent? Proof of damage? Expert opinion? If no to all three → conditional language only.
