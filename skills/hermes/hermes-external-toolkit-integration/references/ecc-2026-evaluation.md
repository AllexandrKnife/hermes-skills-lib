# ECC (Everything Claude Code) — оценка применимости, авг 2026

Результат разбора README (docs/ru/README.md, 1615 строк) для домена пользователя
(СББП/аудит/аналитика, НЕ разработка). Пользователь прислал ссылку
github.com/affaan-m/ECC и спросил «что можно применить у нас».

## Идентификация репозитория (важно — три публичных имени)

Проект намеренно имеет три идентификатора, они НЕ взаимозаменяемы:

- GitHub: `affaan-m/everything-claude-code` (README лежит и по alias-ссылке `affaan-m/ECC`)
- Claude marketplace/plugin: `ecc@ecc`
- npm-пакет: `ecc-universal`

При поиске raw-файлов: default branch = main, путь к русскому README —
`docs/ru/README.md`. Если raw 404 — проверить имя репо (alias vs каноническое),
а не только ветку.

## Текущее состояние (v2.0.0-rc.1, апрель 2026)

- 50 агентов, 185 навыков (SKILL.md), 68 legacy command shims
- Среды: Claude Code (native), Cursor, Codex, OpenCode, Antigravity, Gemini CLI
- MIT, победитель хакатона Anthropic (Cerebral Valley x Anthropic), 140K+ звёзд
- ECC 2.0 alpha (Rust control plane в `ecc2/`) — прототип, НЕ использовать
- Экосистема: AgentShield (npm `ecc-agentshield`), Skill Creator GitHub App,
  continuous-learning-v2 (instincts)

## Вердикт совместимости с Hermes

Совместим ТОЛЬКО `skills/` — формат SKILL.md с YAML frontmatter идентичен
нативному. НЕ совместимо (Claude Code-specific, не переносится):

- `agents/*.md` — определения субагентов (frontmatter tools/model)
- `hooks/` — hook runtime (у Hermes своя архитектура: память, cron, session_search)
- `rules/` — always-follow guidelines, загрузка только через Claude Code
- `commands/` + `legacy-command-shims/` — slash-команды
- `multi-*` команды — требуют внешний runtime `ccg-workflow`
- `mcp-configs/` — у Hermes свой MCP-клиент (native-mcp), использовать только как референс

Установщики `install.sh` / `install.ps1` / `npx ecc-install` — НЕ запускать:
таргетят `~/.claude`, кладут хуки/правила/конфиги, не имеющие Hermes-эквивалента.

## Как читать README проекта

`web_extract` может падать, если web.extract_backend = search-only (DuckDuckGo).
Для raw.githubusercontent.com — curl напрямую:

```bash
curl -sL --max-time 30 https://raw.githubusercontent.com/affaan-m/ECC/main/docs/ru/README.md -o /tmp/ecc_readme.md
```

README большой (1615 строк) — читать read_file порциями по ~400 строк, затем
структурированный разбор (что внутри, что совместимо, что взять/пропустить).

## Отбор для домена «аудит/аналитика/документы» (не код)

Взять (совместимо + полезно):
- `security-scan` / AgentShield — `npx ecc-agentshield scan` CLI-аудит конфигов
  агентов: секреты (14 паттернов), hook injection, MCP risk, permission audit.
  Работает без установки (npx), форматы вывода terminal/JSON/MD/HTML,
  exit code 2 при критических находках. Реальная польза: прогнать против
  ~/.hermes и ~/.claude. У Hermes аналога нет — это главный кандидат.
- `content-hash-cache-pattern` — кеш по SHA-256 при обработке файлов:
  не пересчитывать неизменённые Excel/сметы в пайплайнах.
- `regex-vs-llm-structured-text` — decision framework: когда regex, когда LLM
  для разбора текста (многошапочные Excel, извлечение из смет).
- `cost-aware-llm-pipeline` — model routing + budget tracking.

Уже импортировано ранее (категория `ecc`, 21 скилл): deep-research, search-first,
research-ops, security-review, verification-loop, python-patterns, docker-patterns,
exa-search, market-research и др. НЕ дублировать при повторном импорте.

Пропустить:
- ~70% каталога — языковые/framework скиллы (TS/Go/Rust/Kotlin/Java/Perl/Swift/
  Django/Laravel/Spring/NestJS)
- hooks/, rules/, agents/, commands/, multi-*, MCP configs (см. вердикт выше)
- `skill-stocktake` — пересечение с существующими skill-audit/skill-quality-audit

## Паттерны для концептуального переноса (без импорта)

1. Детект секретов (sk-, ghp_, AKIA) во вводимых промптах — аналог хука
   beforeSubmitPrompt ECC. Релевантно среде пользователя с DLP/KES.
2. Извлечение паттернов из завершённых сессий в навыки с confidence scoring
   (continuous-learning-v2 / instincts) — у Hermes частично делает память,
   можно автоматизировать: cron + session_search → предложение новых скиллов.
3. Дисциплина контекста: <10 MCP-серверов, <80 активных tools, компактификация
   в логических точках (после research, milestone, debugging) — принцип верен
   для любой модели, включая DeepSeek.
