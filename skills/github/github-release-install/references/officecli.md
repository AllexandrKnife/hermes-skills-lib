# OfficeCLI (iOfficeAI) — install + usage notes

Session: 2026-07-31. Evaluated, installed, and smoke-tested.

## What it is

- Repo: iOfficeAI/OfficeCLI. C#, single self-contained binary (.NET embedded), Apache-2.0, ~35 MB linux-x64, ~23.7k stars at install, created 2026-03-15 (young project — verify behavior per case).
- Purpose: Office suite for AI agents — read/edit/create `.docx` / `.xlsx` / `.pptx`. No Office installation required.
- Key differentiator: built-in HTML rendering engine (render docs to HTML/PNG — gives an agent "eyes") and **evaluates Excel formulas (350+ functions)** that openpyxl cannot.

## Install state on this machine (WSL)

- v1.0.143 at `/usr/local/bin/officecli`
- SHA256 verified against release SHA256SUMS (6a29c598...a7)
- `autoUpdate = false` (`officecli config autoUpdate false`; config at `~/.officecli/config.json`; per-invocation skip `OFFICECLI_SKIP_UPDATE=1`)
- CAUTION: `officecli install` / bare invocation injects its SKILL.md into detected AI coding agents — do not run on shared machines; the installed binary itself is inert in this respect.

## Verified capabilities (2026-07-31 smoke test)

openpyxl-written xlsx (formulas as strings, no cached values) — officecli computes them on read:

- `=SUM(A1:A3)` → `1778000`, `computedValue` + `evaluated:true` in JSON
- `=A1*0.22` → `330000`
- `=IF(A1>1000000,"высокий","низкий")` → `"высокий"` (Cyrillic in formulas OK)

→ Closes the openpyxl gap: no LibreOffice recalc round-trip needed when reading formula results.

## Key commands

```
officecli get file.xlsx '/' --json              # full structure: workbook → sheet → row → cell
officecli get file.xlsx '/Sheet/A4' --json       # single cell: formula + computedValue
officecli get file.xlsx '/Sheet/row[4]'          # row by index
officecli query file.xlsx 'row[Сумма>500000]'    # CSS-like selectors, boolean and/or (row[Salary>5000 and Region=EMEA])
officecli view file.pptx html                    # rendered preview (opens browser / headless pipe)
officecli batch file --commands '[{"command":"add",...}]'   # JSON array, one open/save cycle
officecli close file                             # flush resident session to disk (resident auto-flushes 2-10 s idle)
officecli validate file                          # OpenXML schema validation
```

## Use in audit workflow (сметы, ЗКП)

- Formula evaluation: openpyxl can't compute; officecli returns `computedValue` directly → arithmetic sanity checks on сметы without Excel.
- JSON output → straight into the analysis pipeline.
- docx: tracked changes accept/reject by author (`revision.type=ins|del|format`, per-target `/revision[@author=Alice]`) — contract review.
- Render to PNG/HTML → visual check of ЗКП formatting before delivery.

## Limitations

- `.msg` (Outlook) NOT supported — only docx/xlsx/pptx. Keep email-msg-extractor for переписка.
- Multi-header ИНВ-1 sheets (metadata on top of table) — untested; structure parsing is table-oriented, verify on real files.
- Young project (4.5 months at install): on sensitive case data, cross-check results with openpyxl/pandas where cheap.
