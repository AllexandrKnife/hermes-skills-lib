# OpenRouter гео-блок 403 на auxiliary-задачах (11.08.2026)

## Симптом

Auxiliary title generation failed: HTTP 403: {"success": false, "error": "Access denied by security policy."}

В agent.log:
WARNING agent.title_generator: Title generation failed: Error code: 403 - {'success': False, 'error': 'Access denied by security policy.'}

## Диагноз

1. Egress IP: `curl -s https://api.ipify.org` → 217.23.191.60
2. Гео: `curl -s "http://ip-api.com/json/217.23.191.60?fields=status,country,countryCode,regionName,city,isp,org,as"`
   → RU, Tatarstan, Kazan', PJSC TATTELECOM (AS28840)
3. Конфиг: все 14 auxiliary-задач на `provider: openrouter`
   (web_extract, compression, skills_hub, approval, mcp, title_generation,
   tts_audio_tags, triage_specifier, kanban_decomposer, profile_describer,
   curator, monitor, background_review, session_search)
4. Корень: OpenRouter стоит за Cloudflare и режет RU-IP (тот же механизм, что
   у Exa/Tavily — см. cloudflare-ip-block-bypass). За день до этого auxiliary
   перевели на openrouter из-за 400 json_schema от DeepSeek; провайдер в
   конфиге остался openrouter, хотя код уже был пропатчен на json_object.

## Фикс

```bash
for t in web_extract compression skills_hub approval mcp title_generation \
         tts_audio_tags triage_specifier kanban_decomposer profile_describer \
         curator monitor background_review session_search; do
  hermes config set auxiliary.$t.provider deepseek
done
```

Условие работоспособности: title_generator.py использует json_object
(`_TITLE_RESPONSE_FORMAT = {"type": "json_object"}`, патч 10.08.2026) — DeepSeek
принимает json_object. `prefill_messages_file: ''` в конфиге остаётся.

## Проверка (живая, не гадание)

- DeepSeek + json_object: HTTP 200 — urllib-запрос к
  api.deepseek.com/v1/chat/completions с `response_format: json_object`,
  `max_tokens: 50` (ключ из ~/.hermes/.env, значение не печатать)
- Полный путь через код Hermes: `scripts/probe_title_generation.py "..."` → TITLE_OK
- agent.log: WARNING title generation 403 исчезают

## Грабли

- `hermes config set` не перезаписывается при `hermes update` — фикс постоянный.
- Патч json_object в title_generator.py переживёт обновление только через
  autostash-восстановление (правило hermes-maintenance).
- Текущая сессия может держать закешированный auxiliary-клиент со старым
  провайдером — если заголовок всё ещё падает, начать новую сессию.
- `provider: deepseek` резолвит aux-модель из ProviderProfile:
  `default_aux_model="deepseek-v4-flash"`
  (plugins/model-providers/deepseek/__init__.py) — без неё провайдер был бы
  пропущен (`model = _get_aux_model_for_provider(...) or None` → `continue`
  в auxiliary_client.py).
