# Проверка поддержки response_format у LLM-провайдера (curl)

Проверка того, какие response_format типы принимает провайдер, ДО патча кода.
Ключ берётся из ~/.hermes/.env, значение не светится в выводе.

## json_schema (strict) — то, что слал title_generator после обновления

```bash
KEY=$(grep "^DEEPSEEK_API_KEY=" /root/.hermes/.env | cut -d= -f2-)
curl -s -m 30 https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"Return JSON {\"title\":\"test\"}"}],"response_format":{"type":"json_schema","json_schema":{"name":"session_title","strict":true,"schema":{"type":"object","properties":{"title":{"type":"string"}},"required":["title"],"additionalProperties":false}}}}'
```

Результат на DeepSeek (08.2026):
```json
{"error":{"message":"This response_format type is unavailable now","type":"invalid_request_error","param":null,"code":"invalid_request_error"}}
```

## json_object — fallback, который работает

```bash
curl -s -m 30 https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"Return JSON: {\"title\":\"test\"}"}],"response_format":{"type":"json_object"}}'
```

Результат: HTTP 200, content = `{"title":"test"}`.

## Правила json_object у OpenAI-совместимых API

- В промпте ОБЯЗАТЕЛЬНО должно встречаться слово "json" (в любом регистре) — иначе 400
  "`response_format` is only supported with a JSON prompt" или молчаливый игнор
- В _TITLE_PROMPT_TEMPLATE (agent/title_generator.py) оно есть: "Reply with JSON only"
- json_object — базовый формат: работает у DeepSeek, OpenAI, OpenRouter и большинства OpenAI-совместимых
- json_schema (strict) поддерживают OpenAI, OpenRouter, Google Gemini (своим форматом) — НЕ DeepSeek

## Диагностика, где именно шлётся формат

```bash
grep -rn "response_format" /usr/local/lib/hermes-agent/agent/title_generator.py
grep -rn '"json_schema"' /usr/local/lib/hermes-agent/agent/*.py /usr/local/lib/hermes-agent/tools/*.py | grep -v test
```

После `hermes update` — повторить grep: патч мог быть перезаписан.
