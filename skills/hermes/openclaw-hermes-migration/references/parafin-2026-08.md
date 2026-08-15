# Кейс: parafin 204.77.1.107 (2026-08-07)

Реальная миграция OpenClaw → Hermes-клон с сохранением Telegram-бота @WG_BBBot (id 7211165565).

## Исходное состояние

- Ubuntu 24.04.3, 1.9G RAM, диск 15G (2.1G свободно до чистки)
- OpenClaw 2026.4.23 (npm-глобал), сервис openclaw-gateway.service (systemd-user user@0), слушал 127.0.0.1:18789/18791 (pid-процесс openclaw-gatewa)
- Конфиг /root/.openclaw/openclaw.json: channels.telegram = {enabled, botToken, dmPolicy:"pairing", groups:{"*":{requireMention:true}}}; auth.profiles = deepseek:default (api_key)
- /root/OPENCLAW_CREDENTIALS.md (302 байта): DEEPSEEK_API_KEY, OPENCLAW_NO_RESPAWN, NODE_OPTIONS, токен
- /root/.openclaw/: openclaw.json + .backup/.current/.last-good; dirs: agents, canvas, completions, credentials, delivery-queue, devices (paired/pending — device-auth gateway), flows, identity (device-auth.json, device.json), logs, media, memory (main.sqlite — RAG: meta/files/chunks/chunks_fts, chat_id НЕ найден), skills, tasks, telegram (update-offset-default.json: lastUpdateId 105582693, botId), workspace

## Цифры диска

- /usr/lib/node_modules = 3.2G (openclaw@2026.4.23, clawdbot@2026.1.24-3, qwen-code, MCP-серверы, puppeteer-mcp-server)
- npm uninstall -g openclaw clawdbot → «removed 1162 packages in 23s», диск 2.4G → 4.3G
- journalctl --vacuum-size=50M: +50M; apt clean + rm lists: +300M
- purge старых ядер (110/111/117/124): почти ничего (df остался 2.4G) — ядра не главный резерв
- Итог: Hermes install уложился в 4.3G (install.sh: pip venv + managed Node + npm ci TUI, --skip-browser)

## Установка

- install.sh с флагами `--skip-setup --skip-browser` (headless). Флаг --skip-setup пропускает интерактив API-ключей и gateway-мастера; --skip-browser — браузерные зависимости (~1G)
- Системный node v22.22.2 < требуемого >=26 → install.sh поставил Hermes-managed Node
- Время: ~2.5 мин (curl|bash, 1 vCPU); лог-хвост: «hermes was linked into /usr/local/bin», ripgrep отсутствует — fallback grep (не критично)
- Версия: Hermes Agent v0.20.0 (2026.8.3), Python 3.11.15 (install.sh сам поднял)

## Клон личности

- scp /root/.hermes/SOUL.md → /root/.hermes/SOUL.md (авто-загрузка из HERMES_HOME; дефолтный SOUL.md от установщика перезаписан)
- memories/MEMORY.md + USER.md (2.3K + 1.7K)
- skills: 82M tar-пайпом `tar czf - -C ~/.hermes skills | ssh ... 'tar xzf - -C ~/.hermes/'`

## Конфиг (секреты — сервер-сайд)

- .env: `TOKEN=$(jq -r ".channels.telegram.botToken" /root/.openclaw/openclaw.json)`; `DSK=$(grep -oP "DEEPSEEK_API_KEY=\K.*" /root/OPENCLAW_CREDENTIALS.md | tr -d "\r")`; printf в /root/.hermes/.env; chmod 600; в контекст — только имена ключей
- config.yaml минимальный: model (deepseek-v4-flash, provider deepseek, base_url api.deepseek.com/v1), providers.deepseek.thinking.type=enabled, platforms.telegram.enabled=true, extra.status_indicator=true
- getWebhookInfo: url="" → polling, чисто

## Verify-цепочка (все прошло)

1. getMe: ok:true, username WG_BBBot, id 7211165565
2. systemctl is-active hermes-gateway → active
3. /root/.hermes/logs/gateway.log: «[Telegram] Connected to Telegram (polling mode)», «✓ telegram connected», «Set bot status indicator to 'Online'», 60 команд в меню (229 скрыто)
4. CLI-тест `hermes chat -q "кто ты?"` → «агент» (SOUL.md подхвачен, DeepSeek-ключ рабочий)
5. getWebhookInfo повторно: pending_updates=0

## Pairing владельца (выполнено 07.08.2026)

- Владелец написал боту → пришёл pairing-код 4FZFQNDJ
- `XDG_RUNTIME_DIR=/run/user/0 hermes pairing list` → Pending (1): telegram, request-id 40f56ab94d5eff3a, user-id 522912376, «Dmitriy E. Kolchin», 1m ago
- `XDG_RUNTIME_DIR=/run/user/0 hermes pairing approve telegram 40f56ab94d5eff3a` → «Approved! User Dmitriy E. Kolchin (522912376) on telegram can now use the bot»
- `echo TELEGRAM_ALLOWED_USERS=522912376 >> /root/.hermes/.env` + `systemctl restart hermes-gateway` (env читается при старте — рестарт обязателен)
- После рестарта: «Connected to Telegram (polling mode)», «✓ telegram connected», pairing list → «Approved Users (1): telegram 522912376 Dmitriy E. Kolchin»
- Вывод: pairing-код из бота работает как аргумент approve, но request-id из `pairing list` однозначен — использовать его

## Rollback (не выполнялся)

`npm i -g openclaw@2026.4.23`; конфиг из /root/.openclaw.backup-migration; systemctl --user enable+start. Токен не отзывался.

## Наблюдения

- Первый запуск шлюза: 3 WARNING-строки (allowlists не заданы; DNS-over-HTTPS discovery; «Connecting attempt 1/8») — затем connected. WARNING про allowlists — норма, это и есть pairing-режим.
- Порты 18789/18791 после стопа OpenClaw: закрыты (ss -tlnp count 0).
- Параллельно с установкой можно гонять инвентаризацию (getMe, поиск chat_id в sqlite) — не блокирует.
