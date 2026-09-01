---
name: open-source-project-evaluation
version: 1.0.0
description: "Use when Structured evaluation of open-source projects"
critic_status: done
---

# Open-Source Project Evaluation

## When to Use

- User asks to find and evaluate a project: "найди проект X", "оцени X", "дай оценку проекту"
- User wants to compare multiple open-source tools
- Need to assess whether a project is production-ready, hype-driven, or abandoned
- Evaluating an AI/agent tool for self-hosting
- Evaluating a new SaaS/product tool with AI/agent angle ("протестируй X", "прокомментируй X", "вышел новый инструмент X")
- Assessing a tool's MCP/agent compatibility and whether it actually solves a real problem

## Глубина по запросу (пористость)

«Оцени X» в чате (нет явного «рекомендуй к деплою») = шаги 1-3 (найти, baseline, README) + hype-red-flags + проверка «фича открыта?» (прокси-бэкенд, см. Pitfalls). Полный цикл (issues, releases, product mode, 5-мерная оценка 1-10) — только когда вердикт ведёт к РЕШЕНИЮ (деплой/закупка/миграция). Не гонять полный цикл на «просто посмотреть» — экономия без потери качества: baseline ловит 80% вердиктов.

## Workflow

### 1. Find the project

Search GitHub API by keyword:

```bash
curl -s "https://api.github.com/search/repositories?q=<query>&sort=stars&per_page=10"
```

For AI agent projects, add relevant qualifiers: `AI`, `agent`, `self-hosted`, `workspace`.

Always check the **original author's repo** — forks/variants may have lower signal.

### 2. Gather baseline data

Query the repo endpoint:
```bash
curl -s "https://api.github.com/repos/<owner>/<repo>"
```

Key fields to extract:
- **stargazers_count** — community interest
- **forks_count** — derivative work / remixing
- **open_issues_count** — bug burden (high on new projects is expected, high on old is alarming)
- **created_at / updated_at / pushed_at** — age and activity recency
- **language** — primary language
- **license** — legal terms (AGPL-3.0, MIT, Apache-2.0, etc.)
- **topics** — self-applied tags
- **subscribers_count** — dedicated watchers
- **archived** — dead?

### 3. Read the README

```bash
curl -s "https://api.github.com/repos/<owner>/<repo>/readme" | python3 -c "import json,sys,base64; print(base64.b64decode(json.load(sys.stdin)['content']).decode())"
```

Look for:
- Clear quick-start instructions
- Architecture description
- Feature list (what does it actually DO?)
- Dependencies and system requirements
- Security notes
- License terms

### 4. Check language breakdown

```bash
curl -s "https://api.github.com/repos/<owner>/<repo>/languages"
```

Reveals stack composition — Python? JS? Monolith? Microservices?

### 5. Check releases

```bash
curl -s "https://api.github.com/repos/<owner>/<repo>/releases?per_page=3"
```

- No releases + dev branch default = early/unstable
- Semantic versioning + changelog = mature
- Prerelease tags = active development

### 6. Assess the issues

- High issue count in a very new project = growing pains (acceptable)
- High issue count in an old project with low commits = neglect
- Check if maintainers are responding

### 7. Self-hosting fit check (before recommending deployment)

If the verdict is "deploy this", measure the TARGET machine first — never recommend a stack blind:

```bash
nproc; free -h; df -h /; docker ps --format '{{.Names}} {{.Status}}'
```

Compare against each candidate's REAL minimums — many projects state a "min" that means "happy". A 1 vCPU / 957 MiB box cannot run OpenCTI (16 GB), IntelOwl (~4 GB), or MISP (2-3 GB); only lightweight single-process tools fit (SpiderFoot, single-node Node apps). Include the resource table in the verdict so the user sees the constraint, not just the feature list.

## Product / SaaS Evaluation Mode

Use this mode for tools that are open-core, freemium, or commercial — where the product itself (not just the code) matters.

### 1. Name check and discovery

Users often have typos in tool names (e.g. "Palmer Pro" → "Palmier Pro"). Before anything else:
- Search web for the correct product name (check site title, GitHub org, domain)
- Note the company behind it — YC, VC-backed, bootstrapped, solo founder
- Verify the product category and what problem it claims to solve

### 2. Website research (browser)

Navigate to the product website and read:
- **Landing page**: tagline, core value prop, supported models/providers, supported platforms
- **Pricing page**: free tier? what's free vs paid? credit system or flat sub? launch discounts?
- **Docs page**: requirements, setup steps, MCP integration instructions, export formats
- **GitHub repo**: stars, license, language, contributors, open issues, last push

### 3. Read external reviews

Find and read third-party perspectives — blog posts, comparison articles, Product Hunt. Look for:
- What reviewers praise (the real differentiator)
- Where they say it's rough (missing features, platform locks, bugs, name confusion)
- Who they say it's for vs who should skip it
- How new is it? Days vs months vs years

### 4. MCP / AI-agent compatibility check

When evaluating an agent-oriented tool:
- Does it expose an MCP server? What tools does it provide?
- Which coding agents are supported? (Claude Desktop, Codex, Cursor, Claude Code)
- Does the agent see full project context or just a limited view?
- Can the agent take actions (edit timeline, generate assets) or just suggest?

### 5. Pricing analysis

Understand the real cost:
- What's genuinely free vs credit-gated
- Credit burn rates: how much does one unit of work cost
- Worked example: what would a typical use case cost per month
- Is the metering aligned with the user's incentives?

### 6. Verdict: nuisance or necessity?

Structure as:
- **Кому реально нужен**: specific persona + use case where the tool shines
- **Кому не нужен**: who should skip it and why
- **Риски**: platform lock-in, team size, business model fragility, maturity
- **Итог**: one-line take — нишевый/должен иметь/пока сырой/переоценён

---

## Evaluation Framework

Use these dimensions. Score each 1–10 and provide reasoning.

### Architecture (1–10)
Is the design sensible? Monolith vs microservices? Docker-first or bare metal? Is there over-engineering or under-engineering? Technology choice appropriate for the domain?

### Functionality / Feature Completeness (1–10)
Does it deliver on its promise? What's the feature surface? Is there real depth or just a pretty README? For AI agents specifically: tool support, model provider diversity, memory, MCP, web research, email, calendar.

### Stability / Maturity (1–10)
Age, release cadence, issue resolution rate, test coverage signals. New projects (< 30 days) are inherently low here by definition.

### Code Quality (1–10)
Language consistency, repo organization, documentation coverage, CI/CD presence, test infrastructure.

### Community / Hype Factor (1–10)
Separate signal from noise. A project with 70k stars in 3 weeks is viral, not validated. Look at: issue quality (are they real bugs or feature requests?), contributor diversity, discussion tone, third-party forks.

## Pitfalls

- **Viral projects mislead** — PewDiePie publishing a project gets 73k stars in 19 days. Stars are not quality, they're reach.
- **0 issues ≠ good code** — it means nobody's using it.
- **Forks count inflated** — many people fork to star-track, not to contribute.
- **No license = legal grey zone** — AGPL/MIT/Apache matters for commercial use.
- **dev branch as default** — signals pre-1.0, expect breakage.
- **Do NOT use execute_code with subprocess to fetch GitHub API** — use terminal() with curl piped to python3 -c for inline JSON parsing. The timeout is usually 15s, which is enough.
- **"Feature exists" ≠ "feature is open"** — READMEs market features; the repo tree decides. Fetch `contents/` and check whether a headline feature is a *proxy* to a private backend. Example: Osiris RECON toolkit — `src/app/api/scanner/route.ts` just forwards to the author's Tailscale `SCANNER_URL` (default `100.68.100.15:7700`); the backend is not in the repo, without the key every scan 503s. A proxied feature is not self-hostable. Also check which scan types were deliberately removed from the proxy (`deep`, `banner`, `traceroute`, `ports`) — that tells you what the author considers dangerous.
- **Scan for hype red flags** — crypto pump address or "We Get X% on Volume Traded <addr>" in the repo description, repo < 3 months old with a huge star count and fork farm, mono-author + PR-driven commits. All present in Osiris (6.6K stars, 1.4K forks, ~3 months, pump address in the description).
- **Measure the target server BEFORE recommending** — recommended IntelOwl+MISP as "light, fits in an evening" without measuring; the box had 957 MiB RAM and neither fits (min 2-4 GB). Resource check must precede the recommendation, not correct it.

## Reference evaluations

This skill's `references/` directory stores per-project evaluations for future reuse:

- `references/headroom-vs-rtk-evaluation-2026-07-11.md` — Headroom vs RTK: full comparison of token-optimization tools, dependency analysis, resource requirements, and RTK tuning guide
- `references/osint-platforms-landscape-2026-08.md` — OSINT/intelligence platform landscape (Osiris, World Monitor, Omniscope, Crucix, OpenCTI, MISP, IntelOwl, SpiderFoot): positioning, resource minimums, self-hosting fit on a 1 GB VPS
- `references/odysseus-evaluation-2026-06-19.md` — Odysseus evaluation
- `references/palmier-pro-evaluation-2026-06-21.md` — Palmier Pro evaluation (name-confusion case: "Palmer Pro" → "Palmier Pro")

## Russian-Language Output Template

For Russian responses, structure as:

**Проект: <name> от <author>**
<url>

**Статистика**
★ X звезд | Y форков | Z issues | Лицензия: ...

**Стек**
Языки с размерами кодовой базы.

**Функционал**
Что делает, главные фичи.

**Оценка**
- Архитектура: X/10 — ...
- Функциональность: X/10 — ...
- Стабильность: X/10 — ...
- Качество кода: X/10 — ...
- Хайп-фактор: X/10 — ...

**Итог**
Резюме одной строкой: стоит ли смотреть, в каком состоянии, перспективы.
