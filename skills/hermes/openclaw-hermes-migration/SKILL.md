---
name: openclaw-hermes-migration
version: 1.0.0
description: "Use when миграция OpenClaw→Hermes на VPS, тот же бот."
critic_status: done
category: devops
---

# Миграция OpenClaw → Hermes (сохранение Telegram-канала)

Замена агента OpenClaw на Hermes на VPS пользователя с ПЕРЕИСПОЛЬЗОВАНИЕМ того же Telegram-бота (токен из конфига OpenClaw = тот же канал/чат, история чата сохраняется).

## Когда использовать

- «замени openclaw на hermes/клон», «перенастрой на телеграм-канал openclaw»
- Обнаружен openclaw-gateway на хосте флота (см. linux-vps-maintenance/references/vps-fleet.md)
- Любая замена node-агента на VPS (дисковая механика npm-global одинакова)

## Обнаружение OpenClaw на хосте

- Сервис: **systemd-user**, не system: `openclaw-gateway.service` в user@0. Управление: `XDG_RUNTIME_DIR=/run/user/0 systemctl --user stop/disable openclaw-gateway.service`
- Конфиг: `~/.openclaw/openclaw.json` — токен в `channels.telegram.botToken` (формат `<bot_id>:<auth>`, длина ~46), модель в `auth.profiles`, политика чатов `channels.telegram.dmPolicy` (pairing) / `groups.*.requireMention`
- Снапшоты конфига: `openclaw.json.backup/.current/.last-good` — читать основной, не трогать
- Credentials-бэкап: `OPENCLAW_CREDENTIALS.md` в /root (DEEPSEEK_API_KEY и токен)
- Глобальные npm-пакеты: `/usr/lib/node_modules` — openclaw+clawdbot могут занимать **2-3G** (главный резерв диска)
- ID владельца в данных OpenClaw НЕ хранится (pairing динамический; в devices/ только device-auth самого gateway, в memory/main.sqlite — RAG-чанки без chat_id). Не тратить время на поиск.

## Шаги

1. **Pre-flight**: `timeout 10 bash -c 'cat < /dev/null > /dev/tcp/<IP>/22' && echo open`; `free -h`, `df -h /`, версии node/python. Hermes install.sh требует Node >=26 — при старом системном node ставит свой managed node (доп. ~150M).
2. **Инвентаризация с маскировкой**: НИКОГДА не выводить токены в контекст агента. jq-выборка ключей и значений в форме `первый6...последние4`; имена ключей .env — без значений.
3. **Бэкап** (обязателен, rollback): `cp -r ~/.openclaw ~/.openclaw.backup-migration`, `cp OPENCLAW_CREDENTIALS.md *.bak`.
4. **Стоп OpenClaw**: systemctl --user stop + disable (выше). Проверить `ps`/`ss -tlnp` (порты 18789/18791).
5. **Диск**: `npm uninstall -g openclaw clawdbot` (освобождает ~2G), `apt-get clean`, `rm -rf /var/lib/apt/lists/*`, `journalctl --vacuum-size=50M`, purge старых ядер (процедура linux-vps-maintenance). Цель: >=4G свободно.
6. **Установка Hermes**: `curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup --skip-browser` — headless (без интерактива и браузерных зависимостей). 2-5 мин на 1 vCPU, запускать в background+notify.
7. **Клон личности**: `scp ~/.hermes/SOUL.md` (авто-загрузка из HERMES_HOME — `agent/agent_init.py`, `prompt_builder.py`; это и есть идентичность), `memories/MEMORY.md USER.md`, скиллы tar-пайпом (`tar czf - -C ~/.hermes skills | ssh ... 'tar xzf - -C ~/.hermes/'`).
8. **Конфиг**: `.env` писать СЕРВЕР-САЙД из исходников (jq токен из openclaw.json, grep DEEPSEEK_API_KEY из credentials), `chmod 600`; в контекст — только `grep -oE "^[A-Z_]+"`. `config.yaml`: model (deepseek-v4-flash + providers.deepseek.thinking.type=enabled — как у исходного), `platforms.telegram.enabled: true`.
9. **Webhook**: `curl "https://api.telegram.org/bot${TOKEN}/getWebhookInfo"` — url пуст = polling OK; если висит старый webhook — `deleteWebhook`, иначе polling не заведётся.
10. **systemd**: `/etc/systemd/system/hermes-gateway.service`, ExecStart=`/usr/local/lib/hermes-agent/venv/bin/hermes gateway run` (venv-бинарь, не symlink), Restart=on-failure. `systemctl daemon-reload && enable && start`.
11. **Verify**: `systemctl is-active`; `journalctl -u hermes-gateway | grep -i telegram` → «✓ telegram connected (polling mode)»; getMe ok; одноразовый CLI-тест `hermes chat -q "..."` (проверяет ключ LLM + подхват SOUL.md).

## Питфоллы

- **Секреты**: маскировать значения в выводе (sed/jq `первый6...последние4`); записывать секреты в файлы сервер-сайд, не через контекст.
- **deny-by-default + pairing (проверено 08.2026)**: без `TELEGRAM_ALLOWED_USERS` бот отклоняет неизвестных отправителей (лог «No env user allowlists configured... deny unknown senders» — это НОРМА, pairing-режим). Последовательность авторизации владельца:
  1. Владелец пишет боту любое сообщение — бот присылает pairing-код
  2. На VPS: `XDG_RUNTIME_DIR=/run/user/0 hermes pairing list` → pending-запрос (platform, request-id, user-id, name)
  3. `XDG_RUNTIME_DIR=/run/user/0 hermes pairing approve telegram <request-id>` (код из бота тоже принимается как аргумент, но request-id из list однозначен)
  4. Постоянная авторизация: `echo TELEGRAM_ALLOWED_USERS=<user-id> >> ~/.hermes/.env` + `systemctl restart hermes-gateway` — env читается ТОЛЬКО при старте, рестарт обязателен
  5. Повторный verify: gateway.log → «Connected to Telegram (polling mode)», `hermes pairing list` → «Approved Users (1)»
- `hermes pairing` при root-сессии без systemd-user окружения требует `XDG_RUNTIME_DIR=/run/user/0` перед командой.
- **Email-платформу на клоне НЕ включать**, если локальный Hermes уже слушает ту же почту — двойной опрос IMAP, конкуренция за сообщения.
- **Стоп-сервис OpenClaw до старта Hermes с тем же токеном**: два long-poller'а на один токен = 409 и потерянные апдейты. Последовательность: стоп OpenClaw → старт Hermes.
- После миграции обновить `linux-vps-maintenance/references/vps-fleet.md` (состав сервисов хоста).
- Установка создаёт дефолтный SOUL.md в ~/.hermes — перезаписать своим ДО первого запуска шлюза.

## Rollback

`npm i -g openclaw@<версия>` (в реестре была 2026.4.x), конфиг из `~/.openclaw.backup-migration` (файлы .backup/.current/.last-good — снапшоты), пересоздать systemctl --user сервис. Токен не отзывать — он общий для обоих агентов.

## Связанные скиллы

- `linux-vps-maintenance` — доступ к флоту (root-креды, реестр хостов), чистка ядер/диска
- `hermes-agent` — CLI/gateway-справка (bundled, не редактировать)

## References

- `references/parafin-2026-08.md` — реальный кейс 204.77.1.107: точные команды, цифры диска, тайминги, наблюдения.

## Pitfalls

- (заглушка: заполнить известными ошибками и их обходами при использовании)

