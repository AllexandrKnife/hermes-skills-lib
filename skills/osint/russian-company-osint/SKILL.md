---
name: russian-company-osint
version: 1.0.0
description: "Use when OSINT investigation of Russian legal entities"
critic_status: done
---

# Russian Company OSINT

Contractor due diligence and OSINT investigation of Russian legal entities.

## When to Use

- Verify a Russian counterparty/contractor before signing a contract
- Check liquidation status, director, учредители (founders)
- Identify related entities (same director, same brand, predecessor-successor chains)
- Investigate a company mentioned in construction estimates, procurement docs, or invoices
- Cross-reference company data against official registries

## Primary Sources

### 1. ЕГРЮЛ — ФНС (egrul.nalog.ru)

Official Russian tax service registry. The authoritative source — all other aggregators pull from here.

**API workflow (two-step — token expires in seconds):**

```
# Step 1: POST search → get token
TOKEN=$(curl -s "https://egrul.nalog.ru/" -X POST \
  -H "Content-Type: application/json" \
  -d '{"query":"<ОГРН or ИНН or company name>"}' \
  -H "User-Agent: Mozilla/5.0" 2>/dev/null | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['t'])")

# Step 2: GET results with token (must be immediate — token expires fast)
curl -s "https://egrul.nalog.ru/search-result/$TOKEN" \
  -H "User-Agent: Mozilla/5.0"
```

**Key fields in response:**
- `c` — short name
- `n` — full name
- `o` — ОГРН (13 digits for ООО, 15 for ИП)
- `i` — ИНН (10 digits for ООО, 12 for ИП)
- `p` — КПП
- `r` — registration date (dd.mm.yyyy)
- `e` — termination date (absent = active, present = liquidated)
- `g` — director/liquidator info
- `rn` — region

**Search by ИНН of a person** — finds all entities (ООО and ИП) where they appear as director/учредитель.

**Search by ОГРН** — exact match, single result.

**Search by name** — returns partial matches with pagination.

### 2. ЗаЧестныйБизнес (zachestnyibiznes.ru)

Most comprehensive free aggregator. Shows data for both active and liquidated companies.

URL format: `https://zachestnyibiznes.ru/company/ul/<ОГРН>_<ИНН>`

Data available without subscription:
- Full registration details with dates
- Director and учредители with ИНН
- Financials (revenue, employees count)
- ОКВЭД codes
- Legal address history
- Liquidation reason

Data behind subscription (paid):
- Court cases, FSSP enforcement, bankruptcy
- Procurement (goszakupki) history
- Stop-list status (bank blocking)

### 3. Checko (checko.ru)

Alternative aggregator. Filters out liquidated companies by default — toggle "Только действующие" off.

### 4. The Company's Own Website

Check even for liquidated companies — the site may still be operational:
- Extract contact info, catalog, legal entity name from pages
- Cross-reference phone/email/address against ЕГРЮЛ
- Check for discrepancies: different ИНН/ОГРН than what was provided
- CMS fingerprint for tech stack assessment
- Certificate/sertifikat downloads on the site

## Workflow

### Step 1: Collect known identifiers
Get company name, ИНН, ОГРН, legal address from the user or contract docs.

### Step 2: Search ЕГРЮЛ
Search by each identifier. If only a name is provided, search by name and identify the correct entry by matching the address or region.

### Step 3: Determine status
- Active: no `e` field in response
- Liquidated: `e` field with date
- Reason for liquidation:
  - "исключение из ЕГРЮЛ (ст. 21.3)" = налоговый орган исключил за недостоверность сведений (red flag)
  - "ликвидировано по решению учредителей" = добровольная ликвидация (neutral)
  - "реорганизация" = company was reorganized/merged

### Step 4: Check учредители and director
- Search each учредитель/директор ИНН in ЕГРЮЛ
- Identify if they have active entities (ИП or other ООО)
- Cross-reference with the target company's field of activity

### Step 5: Cross-reference with aggregators
Visit zachestnyibiznes.ru for the full picture (financials, additional entities).

### Step 6: Check the website
Visit the company's website. If liquidated but website still works, flag as risk.

### Step 7: Check related entities
- Same name in different regions (predecessor-successor pattern)
- Same brand with different legal entity
- Chain of: Ульяновская entity → Чувашская entity (common migration pattern)

## Pitfalls

- **Liquidated companies may have active websites.** A running site does not mean the company exists. Always verify against ЕГРЮЛ.
- **ФНС API tokens expire in seconds.** Chain POST and GET without delay. Split into separate curl calls if the shell pipeline is unreliable.
- **Aggregators (Checko, Rusprofile) 404 on liquidated companies.** Use zachestnyibiznes for liquidated entities.
- **Same company name in multiple regions.** Always verify by ИНН/ОГРН, not name alone. Different regions may host unrelated entities with the same name.
- **Yandex search from non-Russian IPs consistently triggers captcha.** Use direct site navigation or curl with appropriate User-Agent.
- **Директор/учредитель data:** a person listed as director of a liquidated company may have a separate active ИП — always check by personal ИНН.
- **Добровольная ликвидация vs исключение по ст.21.3:** ст.21.3 (исключение как недействующее) is a stronger red flag than добровольная ликвидация.

## Verification

- Cross-reference company name AND ИНН across at least 2 sources
- For liquidated entities, verify termination date and legal basis
- Check if director/учредитель operates any active entities
- If website exists, confirm the ИНН on site matches ЕГРЮЛ
- For critical decisions, order a свежая выписка из ЕГРЮЛ directly from ФНС

## References

See `references/rumdors-case-study.md` for a worked example of investigating a liquidated door manufacturer whose website still operates.
