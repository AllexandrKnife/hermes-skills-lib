# Миграция скиллов на новый ноутбук — август 2026 (реальный прогон)

## Задача
Перенести document-critic, ask-first, flash-pro-boost + жёсткую автозагрузку
на новый ноутбук со свежеустановленным Hermes. Доставка — через VPS
(перевалочный пункт), как предпочёл пользователь.

## Исходные факты (проверены)
- Скиллы лежат: `~/.hermes/skills/ask-first/`, `~/.hermes/skills/productivity/document-critic/`,
  `~/.hermes/skills/software-development/flash-pro-boost/` — каждый один файл SKILL.md
  (7.8K / 26.4K / 23.9K), без references/scripts.
- Автозагрузка: `~/.hermes/.env` строка 14: `HERMES_TUI_SKILLS=document-critic,ask-first,flash-pro-boost`.
- Локальных путей в SKILL.md нет (единственный `/root/...` в flash-pro-boost имеет
  альтернативу `~/.hermes/config.yaml`).

## Найденный баг в первой версии install.sh
`case ",$CURRENT," in *",$s,"*)` с `CURRENT="$(grep '^HERMES_TUI_SKILLS=' ...)"` —
в строке остаётся префикс `HERMES_TUI_SKILLS=`, поэтому ПЕРВЫЙ элемент списка
(document-critic) никогда не матчится и дублируется при каждом запуске:
```
HERMES_TUI_SKILLS=document-critic,ask-first,flash-pro-boost,document-critic
```
Исправление: `CURRENT_VAL="$(grep '^HERMES_TUI_SKILLS=' file | tail -1 | cut -d= -f2-)"`,
матчинг `printf '%s' ",$VAL," | grep -q ",$s,"`. После фикса все 4 сценария чисты.

## Тест-сценарии (все пройдены)
| Сценарий | Ожидание | Результат |
|----------|----------|-----------|
| свежая установка (нет .env) | строка добавлена | OK |
| повторный запуск | «уже содержит», без дублей | OK |
| строка `=document-critic` | дополнена без дублей | OK |
| строка `=some-other-skill` | чужой сохранён, наши дописаны, остальное не тронуто | OK |

Песочница: `HERMES_HOME=/tmp/fhX` + фейковый `hermes` (printf '#!/bin/bash\nexit 0')
в `/tmp/fakebin`. Сверка копий: `sha256sum` совпал с оригиналами.

## Доставка
- Архив `hermes-skills-migration.tar.gz` (19.7K), sha256 `562b01fdcac3a4d9d84c9904f162eb74ee2e7feaadfeeda44676e695ccc10019`.
- scp (sshpass, пароль root/1qsxdrgb) на 45.134.15.185:/root/ и 204.77.1.107:/root/
  (основной VPS + нода с hermes-gateway).
- Верификация на серверах: `ls -la` + `sha256sum` — хеши совпали на всех трёх копиях.
- Команда забора на новой машине: scp → tar xzf → bash install.sh.

## Выводы на будущее
- VPS-перевалочный пункт — предпочтительный способ доставки файлов между машинами
  пользователя (спросил «как доставить» — ответил «предполагалось что ты положишь на впс»).
- install.sh класть в архив рядом со `skills/` — самодостаточный пакет.
- Прелоад не подхватится без полного рестарта hermes — включить это в инструкцию.
