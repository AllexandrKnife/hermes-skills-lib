# Porting Example: book-to-skill (Claude Code) → Hermes

Concrete walkthrough of importing an Agent Skills standard repo whose SKILL.md is a generator spec, done 2026-07-31.

## Repo reconnaissance

- `curl -sL https://api.github.com/repos/virgiliojr94/book-to-skill` → `default_branch: master` (NOT main — raw `main/*.md` URLs 404)
- Tree via `git/trees/HEAD?recursive=1`: SKILL.md, scripts/extract.py, book_to_skill/ (Python engine: parsers for pdf/epub/docx/html/rtf/text/calibre, sanitize, dependency probing), tools/ (scan_generated_skill.py, validate_skill.py, discovery_tax.py), tests/ (184 tests), docs/
- README: "Turn any technical book PDF into a Claude Code skill" — open Agent Skills standard (agentskills/agentskills), MIT. Works for Copilot CLI, Amp, Claude Code; same SKILL.md format as Hermes.

## What the skill does

Converts books/documents (PDF, EPUB, DOCX, HTML, MD, TXT, RTF, MOBI via Calibre) into a generated agent skill:
- SKILL.md (~4K tokens: core frameworks + chapter/topic indexes)
- chapters/chNN-<slug>.md (per-chapter summaries, loaded on demand)
- glossary.md, patterns.md, cheatsheet.md

Four modes: full conversion, analyze-only, generate-from-analysis, update/fold-in (merge new sources into an existing generated skill).

## Import steps

1. `git clone --depth 1 https://github.com/virgiliojr94/book-to-skill.git /tmp/book-to-skill`
2. `mkdir -p ~/.hermes/skills/productivity/book-to-skill`; copy `scripts/`, `book_to_skill/`, `tools/`
3. Rewrote SKILL.md in place — it is a PROCEDURAL spec (Steps 0–10 the agent executes):
   - Frontmatter: repo had only name+description → added version/author/license
   - Skill roots → `~/.hermes/skills/<category>/<slug>/` (default category productivity)
   - Bash → terminal, Read → read_file, Write → write_file, Glob/Grep → search_files
   - Removed slash-commands (/book-to-skill, /skills reload) and Copilot/Amp/Claude Code reload docs
   - Kept the step numbering, token budgets, quality rules, fold-in workflow verbatim
4. Deps: host python3 has no pip module → `uv pip install --system pypdf ebooklib striprtf pytest`
5. Verification:
   - `python3 -m pytest tests/ -q` → 184 passed
   - `scripts/extract.py --check` → per-format extractor report (what's installed, install commands for gaps)
   - smoke fixture: small .md with "Chapter N" headings → extract.py produced full_text.txt + metadata.json, chapters_detected=4
   - `skills_list` → book-to-skill visible under productivity

## Key takeaways

- Generator skills are self-referential: the SKILL.md body runs the engine it ships with. Copy the whole engine directory, not just SKILL.md.
- The Agent Skills standard makes Claude Code skill repos ~90% importable; the remaining 10% is host adaptation (tool names, skill roots, reload mechanics, slash-commands).
- The generated-book-skill format (small resident core + on-demand chapter files + glossary/patterns/cheatsheet) is a good template for any knowledge-compaction task: density over completeness, front-load SKILL.md, never copy raw source text, keep a topic index so the agent can navigate to the right chapter.
- Chapter detection regexes in the engine handle Arabic/Roman/CJK/Thai/Korean headings — multilingual books segment correctly.
