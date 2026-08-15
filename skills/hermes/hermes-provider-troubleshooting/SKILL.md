---
name: hermes-provider-troubleshooting
description: "Use when Hermes auxiliary tasks fail with provider errors."
critic_status: done
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [hermes, auxiliary, provider, deepseek, response_format, title-generation]
    category: devops
    related_skills: [hermes-agent, debugging-hermes-tui-commands]
---

# Hermes Provider Troubleshooting

Диагностика и фиксы несовместимостей Hermes с LLM-провайдерами: auxiliary-задачи
(title generation, compression, vision, session_search) падают с HTTP-ошибками
провайдера после обновления Hermes или смены модели.

## When to Use (Триггеры)

- Ошибка вида `Auxiliary title generation failed: HTTP 400: This response_format type is unavailable now`
- Ошибка вида `Auxiliary title generation failed: HTTP 403: {'success': False, 'error': 'Access denied by security policy.'}` — запрос ушёл на OpenRouter, см. кейс 11.08.2026 ниже
- Любая auxiliary-задача с HTTP 400/402: "Title generation failed", "compression failed", "session search failed"
- Ошибки появляются ПОСЛЕ обновления Hermes (новые фичи шлют новые параметры, которые старый провайдер не принимает)

## Ключевой факт: DeepSeek и response_format (проверено 10.08.2026, live curl)

DeepSeek API (api.deepseek.com/v1) **не поддерживает** `response_format: {"type": "json_schema", ...}` —
возвращает HTTP 400 `This response_format type is unavailable now` (поле `error.type: invalid_request_error`).
Поддерживает только `{"type": "json_object"}` — при условии, что слово "json"/"JSON" присутствует в промпте.

Это важно, потому что Hermes после обновления (август 2026) начал слать strict json_schema
для генерации заголовков сессий (`agent/title_generator.py`, константа `_TITLE_RESPONSE_FORMAT`),
а у пользователя основной провайдер — DeepSeek, и auxiliary auto-резолв шага 1 берёт
«основной провайдер + основная модель».

## Ключевой факт: DeepSeek и thinking/reasoning (проверено 12.08.2026)

deepseek-v4-pro (и аналоги) по умолчанию отвечает ЧЕРЕЗ reasoning: `reasoning_content`
заполняется, а `content` остаётся пустым, пока reasoning не завершился. При малом
`max_tokens` весь бюджет уходит в reasoning → `finish_reason: length`, `content: ''`,
HTTP 200, usage.reasoning_tokens == completion_tokens. Скрипт, который читает
`choices[0].message.content` и не проверяет finish_reason, получает ПУСТОЙ результат
с exit code 0 — ложный успех.

Симптом: `wc -c` вывода = 1 (пустая строка) при exit 0. На коротких промптах reasoning
успевает завершиться и content заполняется — поэтому «контрольный тест» на 1-2 словах
проходит, а на документе 30KB — пусто. Проверено: при max_tokens=2000 — пусто;
при 8000 — reasoning 7841/7843 токенов впритык, content='OK'.

Фиксы (в порядке предпочтения):
1. `"thinking": {"type": "disabled"}` в payload — ответ приходит сразу в content
   (проверено: completion_tokens=1, content='OK', finish=stop). Для задач «проверка/короткий
   ответ» reasoning не нужен.
2. Если reasoning нужен — max_tokens >= 8000 и проверять finish_reason, не принимать
   пустой content за успех.

Диагностика «пустого успеха»: печатать `repr(content)`, `finish_reason`, `usage` —
не только status_code. Ложный OK опаснее ошибки: он проходит как «замечаний нет».

## Как устроен auxiliary auto-резолв

`agent/auxiliary_client.py`, docstring в начале файла. Для текстовых задач порядок:
1. Основной провайдер + основная модель (config.yaml `model.default` / `model.provider`) — берётся ВСЕГДА, любой тип
2. OpenRouter (OPENROUTER_API_KEY)
3. Nous Portal (~/.hermes/auth.json)
4. Custom endpoint (model.base_url + OPENAI_API_KEY)
5. Native Anthropic
6. Прямые API-ключи (z.ai, Kimi, MiniMax...)

Если в ~/.hermes/.env есть только DEEPSEEK_API_KEY — большинство auxiliary-задач с provider:auto идут на DeepSeek.
ВАЖНО: title_generation — особый случай (fast-model task, см. кейс 11.08.2026): при auto может уйти на OpenRouter, даже когда DeepSeek-ключ есть и работает.

Per-task override: секция `auxiliary:` в config.yaml — `auxiliary.<task>.provider`, `.model`, `.base_url`, `.api_key` (например `auxiliary.title_generation.provider`). Default "auto" = цепочка выше.

## Диагностика (порядок)

1. Лог: `grep -i "title generation failed\|response_format type" ~/.hermes/logs/agent.log | tail -5` — подтверждает задачу и текст ошибки.
2. Конфиг: секция `auxiliary:` в ~/.hermes/config.yaml — какой провайдер/модель у задачи (обычно `provider: auto`, `model: ''`).
3. Код: `grep -n "response_format" /usr/local/lib/hermes-agent/agent/*.py` — где формируется запрос. Установка Hermes живёт в /usr/local/lib/hermes-agent (код + venv).
4. Какие ещё ключи есть: `grep -o -E "^[A-Z_]+=" ~/.hermes/.env | sort` — есть ли альтернативные провайдеры для auto-цепочки.

## Проверка провайдера curl-ом (до правки кода)

```bash
KEY=$(grep "^DEEPSEEK_API_KEY=" ~/.hermes/.env | cut -d= -f2-)
# json_schema → ожидаем 400:
curl -s -m 30 https://api.deepseek.com/v1/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"Return JSON {\"title\":\"test\"}"}],"response_format":{"type":"json_schema","json_schema":{"name":"t","strict":true,"schema":{"type":"object","properties":{"title":{"type":"string"}},"required":["title"]}}}}'
# json_object → ожидаем 200 с {"title":"test"}:
curl -s -m 30 https://api.deepseek.com/v1/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"Return JSON: {\"title\":\"test\"}"}],"response_format":{"type":"json_object"}}'
```

## Фикс title_generation (проверен 10.08.2026)

Патч `agent/title_generator.py` — заменить json_schema на json_object:

1. Бэкап: `cp /usr/local/lib/hermes-agent/agent/title_generator.py /usr/local/lib/hermes-agent/agent/title_generator.py.bak.$(date +%s)`
2. Заменить блок `_TITLE_RESPONSE_FORMAT = {...}` (json_schema, ~12 строк) на:
   ```python
   _TITLE_RESPONSE_FORMAT = {
       "type": "json_object",
   }
   ```
3. Проверить, что в промпте задачи есть слово "json" (для json_object обязательно):
   `grep -n "JSON" /usr/local/lib/hermes-agent/agent/title_generator.py` — в _TITLE_PROMPT_TEMPLATE есть "Reply with JSON only".
4. `python3 -m py_compile /usr/local/lib/hermes-agent/agent/title_generator.py`
5. Другие места с json_schema: `grep -rn '"json_schema"' /usr/local/lib/hermes-agent/agent/*.py` — plugin_llm.py содержит json_schema, но это для плагинов (PluginLlm), не для auxiliary-задач основного провайдера — не трогать.
6. Эффект — в новой сессии Hermes. Если ошибка видна в текущем процессе — перезапустить hermes.

## Кейс 11.08.2026: HTTP 403 «Access denied by security policy» — запрос ушёл на OpenRouter

Симптом: `Auxiliary title generation failed: HTTP 403: {'success': False, 'error': 'Access denied by security policy.'}` — появляется ПОСЛЕ фикса json_object, «внезапно».

Диагностика (критично): формат ошибки `{'success': False, ...}` НЕ равен формату DeepSeek (`{'error': {'message': ...}}`). Это признак ДРУГОГО провайдера/шлюза (OpenRouter, Nous Portal). Подтверждение — строка лога прямо перед ошибкой:
`grep "Auxiliary title_generation: using" ~/.hermes/logs/agent.log | tail`
→ `Auxiliary title_generation: using openrouter (deepseek/deepseek-v4-flash)` = запрос идёт ЧЕРЕЗ OpenRouter, а не на api.deepseek.com. Не доверять конфигу — лог показывает реальный маршрут.

Почему так: title_generation — fast-model task (`_FAST_MODEL_TASKS` в agent/auxiliary_client.py — для неё нужна дешёвая быстрая модель). При provider=auto резолв ищет fast-модель провайдера (`_get_aux_model_for_provider`: живой каталог /v1/models → ProviderProfile.resolve_aux_model → default_aux_model → fallback-dict); для deepseek её НЕ находит (нет в `_API_KEY_PROVIDER_AUX_MODELS_FALLBACK`) → провайдер признаётся непригодным для задачи → fallback на OpenRouter. У пользователя OpenRouter дал: 402 «no credits» (09:00, аккаунт без баланса) и 403 «Access denied by security policy» (10:57, гео-блок RU-IP).

Фикс (проверен 11.08.2026): задать явно в ~/.hermes/config.yaml:
`auxiliary.title_generation.provider: deepseek` (команда: `hermes config set auxiliary.title_generation.provider deepseek`).
Эффект: лог становится `Auxiliary title_generation: using deepseek (deepseek-v4-flash) at https://api.deepseek.com/v1/`, ошибка исчезает. Применяется с новой сессии; текущий процесс держит старый конфиг — перезапустить hermes.
Если захочешь вернуть auto — сначала задай auxiliary.title_generation.model явно (иначе снова OpenRouter).
Live-проверка, что DeepSeek не виноват: curl с ключом из .env, тело как у title_generator (json_object + max_tokens=64) → 200.

## Питфолы

- **Пустой content при exit 0 ≠ успех**: deepseek-v4-pro с reasoning на длинных промптах возвращает `content: ''` с HTTP 200 (весь max_tokens ушёл в reasoning_content). Всегда проверять `finish_reason`/`content` (wc -c вывода), не только код возврата. Лечение: `thinking: {"type": "disabled"}` или max_tokens >= 8000 — см. секцию «DeepSeek и thinking/reasoning».
- **Обновление Hermes перезапишет патч** — после каждого `hermes update` проверять title_generator.py (или следить, не починил ли апстрим).
- Не гадать, поддерживает ли провайдер формат — проверять curl-ом с ключом из .env (см. выше). Текст ошибки "unavailable now" ≠ временный сбой.
- json_object требует слова "json" в промпте — если модель вернула не-JSON, _extract_title_text() имеет loose-JSON fallback, титул всё равно извлечётся.
- Не менять конфиг auxiliary на «ручной» провайдер, если других ключей нет — останется auto и DeepSeek; правильный путь — патч формата или апстрим-фикс.
- Перед правкой кода установки — бэкап файла (правило rollback: точка возврата до деструктивной операции).
- При ручном curl НЕ доставать ключ из ~/.hermes/auth.json `credential_pool.<provider>[0]` — там dict (поля access_token/runtime_api_key, secret_fingerprint), а не строка; передача dict как Bearer → 401 «api key invalid». Рабочий ключ — в ~/.hermes/.env (DEEPSEEK_API_KEY).
- Смотреть реальный маршрут запроса в логе (`Auxiliary <task>: using <provider> (<model>)`), а не полагаться на `provider: auto` в конфиге — auto для fast-model задач (title_generation) резолвится иначе, чем для остальных.
- Для проверки состояния конфига НА МОМЕНТ сбоя — бэкапы: `ls ~/.hermes/config.yaml.bak.*` (mtime бэкапа = состояние до правки; правка конфига в 11:02, ошибки в 10:57 — бэкап 23:33 предыдущего дня показал provider: auto).

## Pitfalls

- (заглушка: заполнить известными ошибками и их обходами при использовании)

