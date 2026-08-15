# DeepSeek: response_format json_schema → HTTP 400 (зафиксировано 10.08.2026)

## Симптом

После обновления Hermes в логе (`~/.hermes/logs/agent.log`):

```
WARNING agent.title_generator: Title generation failed: Error code: 400 -
{'error': {'message': 'This response_format type is unavailable now',
'type': 'invalid_request_error', ...}}
```

## Причина

Новый код генерации заголовков (`agent/title_generator.py`) шлёт
`extra_body={"response_format": _TITLE_RESPONSE_FORMAT}` со strict
`json_schema`. DeepSeek API (`api.deepseek.com`) этот тип НЕ поддерживает.
`auxiliary.title_generation.provider: auto` резолвится на основной провайдер
пользователя (DeepSeek) — первый шаг auto-цепочки в
`agent/auxiliary_client.py`.

## Подтверждение curl-ом (не гадать)

Ключ из `~/.hermes/.env`, только код ответа:

```bash
KEY=$(grep "^DEEPSEEK_API_KEY=" ~/.hermes/.env | cut -d= -f2-)
# json_schema → 400
curl -s -m 30 https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"Return JSON {\"title\":\"test\"}"}],
       "response_format":{"type":"json_schema","json_schema":{"name":"t","strict":true,
       "schema":{"type":"object","properties":{"title":{"type":"string"}},"required":["title"],
       "additionalProperties":false}}}}'
# json_object → 200 + корректный ответ
```

`json_object` работает. Требование json_object у OpenAI-совместимых API:
в промпте должно быть слово «json» — в `_TITLE_PROMPT_TEMPLATE` есть
«Reply with JSON only», условие соблюдено.

## Патч (бэкап → правка → проверка)

```bash
cp /usr/local/lib/hermes-agent/agent/title_generator.py \
   /usr/local/lib/hermes-agent/agent/title_generator.py.bak.$(date +%s)
```

В `agent/title_generator.py` заменить `_TITLE_RESPONSE_FORMAT`:

```python
_TITLE_RESPONSE_FORMAT = {
    "type": "json_object",
}
```

(вместо блока `{"type": "json_schema", "json_schema": {...}}`) + комментарий
с датой и причиной. Проверка: `python3 -m py_compile title_generator.py`.

## Важно

- Файл в `/usr/local/lib/hermes-agent` — `hermes update` перезапишет патч.
  Фикс повторять после каждого обновления, пока апстрим не исправит.
- `_extract_title_text()` имеет loose-JSON fallback — титул извлекается даже
  если провайдер игнорирует response_format.
- Аналог для других auxiliary-задач: тот же паттерн диагностики
  (конфиг → модуль → curl → бэкап → патч).
