# OSINT — Company Verification for Construction Contractors

## When to use

When a contractor references a specific manufacturer for materials (doors, tiles, countertops, sanitary ware), especially when product passports, certificates, or declarations become available during inspection.

## Typical scenario

1. Estimate says: "материал EGGER H1145 ST10" implying EGGER-made doors
2. Site engineer provides photos of door passport/certificate
3. Passport shows: manufacturer ООО «РУМДОРС» (Room Doors), ИНН 2130230908
4. OSINT check reveals company was liquidated 16.01.2024
5. Passport date: 09.06.2026 — 2.5 years after liquidation

## Full legal qualification chain (all levels)

When product passport issued by liquidated company:

**Уголовно-правовая (при установлении умысла):**
- Ст. 327 ч.1 УК РФ — подделка официального документа (паспорт изделия), предоставляющего права (право на гарантийное обслуживание), совершённая в целях его использования. Санкция: до 2 лет лишения свободы.
- Ст. 327 ч.3 УК РФ — использование заведомо подложного документа (предъявление паспорта несуществующего юрлица при сдаче работ). Санкция: до 80 000 руб штрафа.
- Ст. 159 ч.2 УК РФ — мошенничество (если цена завышена вследствие введения в заблуждение относительно производителя). Санкция: до 300 000 руб штрафа / до 5 лет лишения свободы.

**Административно-правовая (бесспорна, не требует умысла):**
- Ст. 14.7 КоАП РФ — обман потребителей (введение в заблуждение относительно потребительских свойств товара). Санкция: до 500 000 руб.
- Ст. 14.45 КоАП РФ — реализация продукции, подлежащей обязательной сертификации, без сертификата соответствия. Санкция: до 300 000 руб.

**Гражданско-правовая (по SC W-1/договору):**
- Ст. 431.2 ГК РФ — заверения об обстоятельствах. Если подрядчик заверил, что поставит двери EGGER, а поставил от другой фабрики — возмещение убытков + штраф 10% от суммы заверения (ст. 431.2 ч.2 ГК РФ).
- Ст. 469, 475 ГК РФ — передача товара ненадлежащего качества. Последствие: соразмерное уменьшение цены, замена товара, расторжение договора.
- П. 9.1.3 SC W-1 — право на односторонний отказ от договора при использовании материалов, отличных от указанных в смете.
- П. 5.2.1 SC W-1 — материалы должны быть новыми. Дверь произведена юрлицом, ликвидированным за 2 года до даты изготовления — законность происхождения не подтверждена.

## Proving intent (доказывание умысла)

Chain of evidence to build:
1. Product passport with date after liquidation → ст. 327 ч.1
2. Contractor's purchase documents: if supplier ≠ liquidated company → contractor KNEW they weren't buying from them, used their forms → ст. 327 ч.3
3. If supplier = liquidated company → documents issued after liquidation → ст. 327 ч.1 or fraud by third party
4. Price markup (33,650 vs market 14-18k) + false manufacturer claim → ст. 159 ч.2

## Document request to prove intent

When asking contractor for documentation, request specifically:
1. Накладные / УПД / счета-фактуры на двери + поставщик (ИНН) + цена за единицу
2. Договор поставки или счёт
3. Сертификат соответствия / декларацию на двери (с указанием органа, выдавшего сертификат)
4. Паспорт изделия (копия)

Any of three outcomes works:
- Не предоставил → сокрытие, presumption against them
- Предоставил с другим поставщиком → знал, что документы подложные → прямой умысел
- Предоставил от ликвидированной компании → фиктивный документ налицо

## Date nuance — «дата изготовления» vs «дата продажи»

When the passport shows a date but does NOT have the label «дата изготовления» or «дата продажи»:

- Default assumption (ГОСТ 2.601): date in passport without label = дата изготовления (date of manufacture)
- Exception: товар может быть произведён ДО ликвидации (завод выпустил и продал), а продан ПОСЛЕ — это законно
- If the manufacturer was liquidated BEFORE the date shown and the date is NOT labeled → two possibilities:
  a) Date is дата изготовления — impossible (company didn't exist) → passport is fraudulent
  b) Date is дата продажи — possible (goods sold after liquidation) → need supporting documents (invoice, bill of lading)
- **Key practical test**: The presence of an ОТК (quality control) stamp WITHOUT a date supports interpretation (a) — the QC stamp should match the manufacture date. If QC stamp has no date, it could have been applied at any time.
- **Negotiation response if contractor says «это дата продажи, не изготовления»**: «Хорошо. Покажите накладную — когда и от кого вы купили эти двери. Если поставщик ≠ ликвидированная компания — мы имеем дело с добросовестным приобретением, но кто несёт гарантию? Если поставщик = ликвидированная компания — счёт после ликвидации невозможен. В любом случае нужны документы.»
- **Documents to request**: накладные, УПД, договор поставки, счёт

## Key evidence path

Passport itself → expert evaluation confirms it's a counterfeit → criminal complaint under ст. 327 УК РФ.

| Issue | Consequence |
|-------|-------------|
| Company liquidated before contract | Goods of unknown origin |
| Passport dated after liquidation | ст. 327 УК РФ — подделка документов (до 2 лет) |
| No valid certificate | п. 5.2 SC W-1 — materials must be certified |
| No warranty recourse | п. 3.1 — guarantee void without manufacturer |
| Unknown production origin | Product safety and fire compliance uncertain |

## Quick reference — key Russian databases

- **ЕГРЮЛ**: nalog.gov.ru — check company status, liquidation date, reason
- **ФНС check**: focus on: ликвидировано, исключено из ЕГРЮЛ, недостоверные сведения
- **Арбитраж**: kad.arbitr.ru — check for lawsuits involving the company
- **Росаккредитация**: fsa.gov.ru — verify certificates of conformity
- **ФССП**: fssp.gov.ru — check enforcement proceedings

## Example from practice

> ООО «РУМДОРС» (ИНН 2130230908), г. Чебоксары, ул. Ленинского Комсомола, 27
> - Зарегистрировано: 16.03.2022
> - Ликвидировано: 16.01.2024 (исключение по ст. 21.3 №129-ФЗ — недостоверные сведения)
> - Уставный капитал: 10 000 руб
> - Сотрудников: 5
> - Доход: ~4,3 млн руб
> - Производство: г. Новочебоксарск, Промышленная 75П/3
> - ОКВЭД: 16.23 — Производство деревянных конструкций

Key finding: дверь по паспорту изготовлена 09.06.2026 — через 2,5 года после ликвидации изготовителя.
