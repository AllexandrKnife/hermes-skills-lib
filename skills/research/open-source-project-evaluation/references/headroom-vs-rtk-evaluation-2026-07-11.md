# Headroom (headroomlabs-ai/headroom) — Evaluation

**Дата:** 2026-07-11
**Контекст:** Сравнительная оценка с RTK (Rust Token Killer) для задачи сжатия контекста LLM на VPS с ограниченными ресурсами (1 CPU, 1 GB RAM, 7.8 GB диск).

---

## Проект: headroomlabs-ai/headroom

**Статистика:** ★58,480 | 4,318 forks | Apache-2.0 | Python | Created 2026-01-07
**Репозиторий:** https://github.com/headroomlabs-ai/headroom
**Документация:** https://headroom-docs.vercel.app/docs
**Docker:** `ghcr.io/chopratejas/headroom:latest`

**Описание:** Прокси-слой сжатия контекста для AI-агентов. Сжимает вывод тулов, логи, RAG-чанки, файлы, историю диалога перед отправкой в LLM. 60–95% меньше токенов, те же ответы.

### Что внутри

| Компонент | Назначение |
|---|---|
| **ContentRouter** | Определяет тип контента, выбирает нужный компрессор |
| **SmartCrusher** | Семантическое сжатие JSON (массивы, словари, вложенные объекты) |
| **CodeCompressor** | AST-компрессия Python, JS/TS, Go, Rust, Java, C/C++, Perl |
| **Kompress-v2-base** | HF-модель, обученная на трейсах агентов (ML-сжатие текста) |
| **CacheAligner** | Стабилизация префиксов для попадания KV-кэша провайдера |
| **CCR (Cache & Compress Reversible)** | Обратимое сжатие — оригиналы хранятся локально, LLM может запросить при необходимости |

### Режимы работы

1. `headroom wrap <agent>` — обёртка Claude Code, Codex, Copilot, Cursor, Aider, Cline, Continue, Goose, OpenHands, OpenCode, OpenClaw и других
2. `headroom proxy --port 8787` — прокси без изменения кода
3. `compress(messages)` — библиотека Python/TypeScript
4. MCP сервер — `headroom_compress`, `headroom_retrieve`, `headroom_stats`

### Дополнительно

- `headroom learn` — анализ неудачных сессий, запись коррекций в `CLAUDE.local.md`
- Cross-agent memory — общая память между Claude, Codex, Gemini с auto-dedup
- Output token reduction — сжатие того, что модель пишет в ответ (не только ввод)
- Image compression — 40–90% через ML-роутер

### Зависимости (полные)

**[all] включает:**
- `tiktoken`, `pydantic`, `litellm` (lazy), `click`, `rich`, `opentelemetry-api`, `ast-grep-cli`
- `[proxy]`: fastapi, uvicorn, httpx[http2], openai, mcp, magika, zstandard, websockets, onnxruntime, transformers, watchdog, sqlite-vec
- `[code]`: tree-sitter + tree-sitter-language-pack (нативные модули под 7 языков)
- `[ml]`: torch, transformers, huggingface-hub (Kompress-v2-base ~200-300 MB)
- `[memory]`: sqlite-vec, sentence-transformers
- `[relevance]`: fastembed (BAAI/bge-small-en-v1.5), numpy
- `[image]`: pillow, sentencepiece, rapidocr-onnxruntime, onnxruntime

**Рантайм-артефакты (скачиваются при первом запуске):**
- `cdn.pyke.io` — ONNX Runtime для Rust-ядра (~20 MB)
- `huggingface.co` — kompress-v2-base модель (~200-300 MB)
- Magika ONNX-модели (~15 MB)

**Внешние бинарники:**
- RTK — поставляется встроенным для shell-вывода (первый слой компрессии)
- tree-sitter — нативные модули под каждый язык

**Системные требования:**
- Python ≥3.10
- AVX2 на x86 для ONNX-фич (иначе fallback на BM25/эвристики)
- Для `[vector]`: C++ toolchain (hnswlib, не входит в `[all]`)

### Затраты ресурсов

| Конфигурация | Диск | RAM |
|---|---|---|
| `[all]` | ~500-600 MB | ~1 GB+ |
| `[proxy]` без torch | ~150-200 MB | ~300-400 MB |
| Голое ядро (без proxy, ML, code) | ~80 MB | ~200 MB |

---

## Сравнение: Headroom vs RTK

| Характеристика | Headroom | RTK (v0.42.0) |
|---|---|---|
| **Scope** | Всё: вывод, JSON, файлы, код, RAG, история, изображения | Только CLI-вывод (shell-команды) |
| **Тип компрессии** | ML + AST + JSON-семантика | Эвристики: обрезать, суммировать, убрать рамки |
| **Обратимость** | Да (CCR — оригиналы кешируются) | Нет (сжатие необратимо) |
| **Работа с кодом** | AST-парсинг (7 языков) | Нет |
| **CacheAligner** | Да (KV-кэш провайдера) | Нет |
| **Cross-agent memory** | Да (Claude + Codex + Gemini) | Нет |
| **Output token reduction** | Да | Нет |
| **Режимы** | wrap, proxy, library, MCP | CLI-wrapper только |
| **Экономия на JSON** | 60-95% | N/A |
| **Экономия на shell** | 15-20% (через встроенный RTK) | 15-25% |
| **Зависимости** | Много (~20 пакетов + ML-модели + ONNX) | Один бинарник (Rust) |
| **RAM** | ~200 MB – 1 GB+ | ~5-10 MB |
| **Установка** | pip install "headroom-ai[all]" | Один бинарник |
| **Лицензия** | Apache-2.0 | Проприетарная? |

### Когда Headroom нужен

- Работаешь с JSON-heavy выводами (массивы, структуры, API-ответы) — 60-95% экономии
- Нужна обратимая компрессия (CCR) — LLM может запросить оригинал при необходимости
- Работаешь с несколькими агентами и нужна shared memory
- Готов выделить 1 GB+ RAM и ~500 MB диска

### Когда хватит RTK

- Всё, что ты делаешь — shell-команды (ls, cat, grep, git, docker, pip)
- VPS с < 1 GB RAM — Headroom c [ml] не влезет
- Не нужна shared memory между агентами
- Не нужна работа с JSON/RAG/изображениями

---

## RTK — как повысить эффективность

**Текущие метрики на этом VPS:** 402 команды, 680.6K токенов сохранено (24.9%).

### Проверенные способы

1. **TOML-фильтры** — `.rtk.toml` с правилами трансформации для команд, которых нет в RTK (systemctl, journalctl, free, ip). `rtk trust <dir>` после создания.
2. **Конфиг** — уменьшить `passthrough_max_chars`, `grep_max_results`, `max_width` в `~/.config/rtk/config.toml`:
   ```toml
   [display]
   max_width = 80
   [limits]
   passthrough_max_chars = 500  # было 2000
   grep_max_results = 50        # было 200
   ```
3. **exclude_commands** — убрать из rewrite команды с нулевой экономией (echo, cd, mkdir, rm, touch, cp, mv).
4. **`rtk gain`** — мониторинг: `rtk gain -g` (график), `rtk gain -a` (все срезы).
5. **`rtk discover`** — поиск пропущенных возможностей (сканирует Claude Code сессии, для Hermes не релевантно).

### `--ultra-compact` не работает

На v0.42.0 флаг `--ultra-compact` даёт 0 байт вывода на некоторых командах (баг). Не использовать.

### Hermes-плагин

RTK v0.42 поставляется с `rtk init --agent hermes`, который уже установлен как плагин `rtk-rewrite` в `~/.hermes/plugins/`. Плагин вызывает `rtk rewrite <cmd>` в pre_tool_call хуке и подменяет команду если RTK предлагает эквивалент.
