---
name: russian-construction-audit
version: 1.0.0
description: "Use when Analyse Russian construction estimates for"
critic_status: done
platforms: [linux]
---

# Russian Construction Cost Analysis (Фрод-анализ смет)

## When to Use

Use this when the user — typically a Russian economic security officer — provides a construction cost estimate (смета) and wants:

- Verification of prices and volumes against market data
- Identification of potential fraud indicators  
- Quantified economic effect (overpayment estimate)
- Document (.docx) with tables, risk ratings, and clickable source URLs

## Prerequisites

- `python-docx` installed: `uv pip install --system python-docx`
- Working Russian sources (see `references/sources.md`)

## Core Workflow

### 1. Arithmetic Check

Verify the estimate's internal arithmetic:
- Sum of work items + material items = total
- NDS calculation: `total * 0.22` (22% rate in RF from 2026)
- Grand total with NDS

### 2. Source-Specific Price Verification

**IMPORTANT:** From outside Russia, most search engines (Google, Yandex, Bing) and retail sites (lemanapro.ru, petrovich.ru) block via captcha. Use what works:

| Site | Status | How |
|------|--------|-----|
| **stroylandiya.ru** | ✅ Works | Price sliders via `data-min`/`data-max` attributes. Use `curl` with Yandex Browser UA. |
| **avito.ru** (Саратов) | ⚠️ 1st search works | After that IP is rate-limited. Reuse subagent. |
| **lemanapro.ru** | ❌ From outside РФ | Qrator bot protection. Ask user to check from Russia. |
| **egger-russia.ru** | ✅ Works | Catalog only. No retail prices — just decor codes. |
| **tdserver.ru** | ✅ Works | Egger LDSP distributor. |
| **market.yandex.ru** | ⚠️ 200 или 403 | Статус нестабилен (07.2026: 200 в одной проверке, 403 в другой) — проверять каждый раз |
| **petrovich.ru** | ❌ Access denied | Blocked. |
| **vseinstrumenti.ru** | ❌ JS-render | Blocked. |

### 3. Subagent Parallel Search

When search engines block, delegate the search:

```python
delegate_task(
    goal="Find specific prices for ...",
    context="Target: ... Use browser_navigate or curl to access ...",
    role="leaf"
)
```

### 4. Build Overpricing Table

For each item, create a row with:

- Estimate price vs market price (range)
- Source URL (clickable hyperlink in docx)
- Risk rating (КРИТИЧЕСКАЯ / ВЫСОКАЯ / СРЕДНЯЯ / НИЗКАЯ)
- Overpayment estimate in rubles

### 5. Quantify Economic Effect

Calculate three scenarios:
- **Минимальный** (partial win)
- **Реалистичный** (full overpricing deduction)
- **Максимальный** (overpricing + 10% holdback + interest)

### 6. Generate .docx Report

Include:
- Section 0: Methodology + source table (which sites worked/blocked)
- Section 1: Arithmetic check
- Section 2: Item-by-item analysis with data tables
- Section 3: Summary table with totals
- Section 4: Counter-arguments (what contractor may object)
- Section 5: Recommendations

Use `add_source()` helper for clickable hyperlinks.

## Key Technical Notes

### Stroylandiya Price Extraction

Price sliders expose data in HTML:
```html
data-min="626" data-max="626"
```
Use regex: `re.findall(r'data-min="(\d+)" data-max="(\d+)"', data)`

### EGGER Decor Codes

EGGER H1145 ST10 is a **decor code** (laminate pattern), NOT a door model.
- H1145 = decor "Дуб Бардолино натуральный"
- ST10 = surface structure "Шероховатые глубокие поры"
- EGGER manufactures LDSP (chipboard), not finished doors
- The actual door is from an unnamed factory using EGGER laminate
- Source: egger-russia.ru, tdserver.ru, lemanapro.ru
- ❗ **Критическое уточнение:** если заказчик подтвердил, что в смете подразумевались ЛЮБЫЕ двери с ламинацией EGGER — аргумент «EGGER не производит двери → введение в заблуждение» утрачивает силу. Проверять трактовку заказчика перед использованием аргумента.

### Clickable Hyperlinks in .docx

```python
def add_hyperlink(paragraph, text, url):
    part = paragraph.part
    r_id = part.relate_to(url, 
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink',
        is_external=True)
    hyperlink = OxmlElement('w:hyperlink')
    hyperlink.set(qn('r:id'), r_id)
    # ... create colored underlined run
```

## SC W-1 Penalty Calculation (for Beeline/ВымпелКом contracts)

When the user provides Special Conditions (SC W-1), calculate delay penalties:

**П. 8.1 SC W-1 — неустойка за просрочку работ:**
- ≤14 дн: 0.2%/день
- 14-30 дн: 0.3%/день
- **>30 дн: 0.4%/день** (на весь период, с первого дня)

Formula: `work_cost × rate × delay_days`

Always check also: п. 8.2 (documents), 8.3 (defects), 8.4 (subcontractors), 8.6-8.7 (workers), 8.8 (advance return), 8.9 (damages beyond penalty), 9.1.2 (termination right), 9.1.3 (material non-conformance), 9.4.2 (no payment for incomplete work).

**Multi-contract check:** Compare identical line items across contracts — identical prices = systematic overpricing, not random errors.

**Negotiation structure:**
1. Calculate penalty (SC 8.1) + overpricing (art. 1102 CC + p. 2.4 contract)
2. Propose: forgive penalty in exchange for price reduction
3. New price = original - overpricing deduction
4. Fallback: p. 9.1.2 termination + p. 9.4.2 no payment for incomplete work

## OSINT Supplier Verification

Before accepting supplier claims in estimates, verify the supplier's legal status via open registries (nalog.gov.ru, list-org.com):

### ЕГРЮЛ Checkpoints
- **Status:** действующее / ликвидировано / реорганизовано
- **Date of liquidation:** if before the contract or claimed manufacture date — critical
- **Grounds:** ст. 21.3 129-ФЗ (недостоверные сведения) = worst case
- **Уставный капитал:** ≤10 000 руб = red flag
- **Сотрудники:** 1-5 = possible shell
- **Доходы:** consistent with contract size?

### Document Cross-Check (two-response analysis)
When you receive two responses about the same issue from different sources, cross-reference:
- Сертификаты: есть или нет?
- Предупреждение о просрочке: устно или не было?
- Журнал работ: ведётся или нет?

### Door Passport Verification
1. Photo the passport — manufacturer, date, OTK stamp, TU number
2. Check manufacturer in ЕГРЮЛ — exists? When liquidated?
3. Check manufacture date — predates or postdates liquidation?
4. Cross-check: estimate says "EGGER" but passport says liquidated "ООО РУМДОРС" = п. 9.1.3 SC W-1 violation

### Full Legal Qualification (supplier liquidated before document date)
**Уголовная:** ст. 327 УК РФ (подделка документов, до 2 лет), ст. 159 УК РФ (мошенничество)
**Административная:** ст. 14.7 КоАП (обман, до 500 тыс — ТОЛЬКО при потребительском характере отношений; в B2B не применима, вместо неё ст. 431.2 ГК / ст. 15, 393 ГК), ст. 14.45 КоАП (без сертификата, до 300 тыс)
**Гражданская:** п. 9.1.3 SC W-1 (отказ от договора), ст. 431.2 ГК РФ (заверения; штраф 10% — если предусмотрен договором), ст. 469/475 ГК РФ (ненадл. качество)

### Document Request (to prove intent, via contract manager)
Request: накладные/УПД на спорные материалы, сертификат, договор поставки, паспорт изделия.
Срок: 5 раб. дней. Основание: п. 1.3.5 ТЗ, п. 5.3 SC W-1.
Санкция за непредоставление: отказ в КС-2 / одностороннее уменьшение цены; при признаках преступления — инициирование проверки в порядке ст. 144 УПК РФ.

## Key Phrases for Reports

- "EGGER H1145 ST10 — ЭТО НЕ МОДЕЛЬ ДВЕРИ, А ОБОЗНАЧЕНИЕ ЛАМИНАЦИОННОГО ПОКРЫТИЯ"
- "Если у подрядчика есть накладная — цена может быть обоснована. Без накладных — принимать оценку по рынку."
- "Из них на основе прямых ссылок: X руб. Экспертная оценка: Y руб."

## Pitfalls

- **Leroy Merlin does not exist in Russia.** It rebranded to Лемана ПРО (lemanapro.ru). Never cite leroymerlin.ru.
- **NDS rate:** 22% from 2026 in RF (not 20%). Don't flag it as an error.
- **EGGER is a decor, not a door.** Don't search for "EGGER door" — search for the decor code on door factory sites.
- **Avito rate-limits hard.** One good search per IP per session. Use subagents.
- **Commercial vs residential.** Prices for legal entities (гарантия 12 мес, сертификаты, ЭДО) are 15-30% higher than retail/Avito.
- **Inflation gap.** If estimate is 2+ months old, note 2-5% potential price change.

## Verification

- All price claims in the report must have a source URL (working or noted as blocked)
- Confirmed data (from Stroylandiya/Avito) must be separated from expert estimates
- Internal contradictions (item in multiple risk categories, double-counting) must be eliminated before final delivery

## Reference Files

See `references/` for:
- `references/sources.md` — general site status table
- `references/russian-sources-2026.md` — detailed Stroylandiya/curl technique
- `references/supplier-liquidation-qualification.md` — full legal qualification when supplier is liquidated
