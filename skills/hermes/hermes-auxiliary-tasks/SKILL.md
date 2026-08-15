---
name: hermes-auxiliary-tasks
description: "Use when Hermes auxiliary tasks fail: HTTP 400, json_schema."
critic_status: done
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [hermes, auxiliary, troubleshooting, providers]
    related_skills: [hermes-agent, systematic-debugging]
---

# Hermes Auxiliary Tasks — диагностика и фиксы

## When to Use

- Ошибка вида "Auxiliary title generation failed: HTTP 400 ..." / "This response_format type is unavailable now"
- Молчаливые отказы фоновых задач Hermes (compression, vision, session search, web extract)
- Настройка провайдера/модели для auxiliary.<task> в config.yaml
- После `hermes update` появилась новая ошибка в фоновых задачах (обновления приносят новый код, который может слать форматы, не поддерживаемые провайдером)

## Как устроено (факты, проверено 08.2026)

- Auxiliary-задачи резолвят провайдера по auto-цепочке (agent/auxiliary_client.py, docstring в начале файла):
  1. Основной провайдер + основная модель (для текстовых задач — всегда шаг 1)
  2. OpenRouter (OPENROUTER_API_KEY)
  3. Nous Portal (~/.hermes/auth.json)
  4. Custom endpoint (model.base_url + OPENAI_API_KEY)
  5. Native Anthropic
  6. Direct API-key провайдеры (z.ai, Kimi, MiniMax...)
- Per-task override: `auxiliary.<task>.provider/model/base_url/api_key` в config.yaml (секция `auxiliary:`)
- Логи ошибок: ~/.hermes/logs/agent.log — `grep -i "title generation failed\|response_format" ~/.hermes/logs/agent.log | tail`
- `extra_body` (в т.ч. response_format) передаётся провайдеру КАК ЕСТЬ — даунгрейда формата в auxiliary_client.py нет
- HTTP 402/credit-ошибки ретраятся авто-цепочкой; HTTP 400 — нет

## Диагностика (порядок)

1. Лог: найти точный текст ошибки и имя задачи (title generation / compression / ...)
2. Конфиг: `auxiliary.<task>.provider` — обычно "auto" → значит, используется основной провайдер
3. Код: grep по agent/*.py — где задача шлёт запрос (например, title_generator.py: `call_llm(task="title_generation", ..., extra_body={"response_format": ...})`)
4. Проверить поддержку формата у провайдера живым curl — см. references/deepseek-response-format.md (команда готовая)
5. Патч кода ИЛИ переопределить auxiliary.<task>.provider на поддерживающий формат провайдер

## Известные проблемы и фиксы

### DeepSeek: json_schema → HTTP 400 "This response_format type is unavailable now"
- DeepSeek API НЕ поддерживает `response_format: {"type": "json_schema", ...}` (проверено curl 08.2026)
- Поддерживает `{"type": "json_object"}`, НО требует слово "json"/"JSON" в промпте (в _TITLE_PROMPT_TEMPLATE оно есть: "Reply with JSON only")
- Фикс (применён 08.2026): в agent/title_generator.py заменить `_TITLE_RESPONSE_FORMAT` с json_schema-блока на `{"type": "json_object"}`. Парсер `_extract_title_text()` имеет loose JSON scan fallback, так что титул извлекается даже если провайдер игнорирует формат.

### Патч кода установки (/usr/local/lib/hermes-agent/)
- `hermes update` перезапишет патч — после каждого обновления проверять: `grep -n "json_schema\|json_object" agent/title_generator.py`
- Перед патчем: `cp file file.bak.$(date +%s)`
- После патча: `python3 -m py_compile file`
- Ошибка исчезает в НОВОЙ сессии (текущий процесс держит старый код в памяти) — сказать пользователю перезапустить hermes

## Pitfalls

- "auto" = основной провайдер. Если у пользователя только DEEPSEEK_API_KEY — ВСЕ auxiliary-задачи идут в DeepSeek, и любая новая фича с неподдерживаемым форматом упадёт именно так
- Не хардкодить имя провайдера в условии патча — предпочесть универсальный формат (json_object работает у всех OpenAI-совместимых)
- Не путать: json_schema не поддерживается DeepSeek, но может поддерживаться другими (OpenAI, OpenRouter) — если провайдер сменится, json_object всё равно работает
- Диапазон проблемы шире title: если обновление добавит json_schema в compression/vision-задачи — тот же паттерн (grep по agent/*.py на предмет "json_schema")

## Поддержка

- references/deepseek-response-format.md — curl-рецепт проверки response_format у провайдера
