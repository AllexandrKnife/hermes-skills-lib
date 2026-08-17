# hermes-skills-lib — библиотека доменных скиллов

Вынесенные из ~/.hermes/skills доменные скиллы: в Hermes остаются только
оркестраторы (network-infra, hermes-agent, osint, github-workflow, academic,
smeta-audit), которые по таблице триггеров читают SKILL.md из этого репо.

Структура: skills/<категория>/<имя>/SKILL.md (+ supporting files).
Оркестраторы в ~/.hermes/skills ссылаются на пути здесь.

Категории: network/ (сеть/VPN/роутеры/VPS/WSL), hermes/ (администрирование
Hermes), osint/ (разведка), github/, academic/, construction/ (сметы).

## Установка всей инфраструктуры на новой машине

Одна команда (скрипт публичный, токен нужен только для приватных репо):

```bash
curl -fsSL https://raw.githubusercontent.com/AllexandrKnife/hermes-skills-lib/main/install-skills.sh | bash
```

Скрипт клонирует/обновляет 5 репозиториев:
- hermes-skills → ~/.hermes/skills (активные скиллы)
- hermes-skills-lib → /root/hermes-skills-lib
- hermes-triz-core → /root/hermes-triz-core
- eko-core → /root/eko-core
- hermes-soul → /root/hermes-soul (версионирование SOUL.md)

Токен берётся из env GITHUB_TOKEN, ~/.git-credentials или интерактивного ввода.
Идемпотентен: повторный запуск делает git pull. --base-dir — для песочницы.

Режимы (автоопределение):
- root (id -u == 0): библиотеки в /root/... — пути оркестраторов совпадают.
- user: библиотеки в $HOME/... — скрипт переписывает /root/... → $HOME/...
  во всех .md файлах hermes-skills (sed), иначе оркестраторы не найдут библиотеки.

Внимание (user-режим): перед обновлением hermes-skills локальные правки скиллов
сбрасываются (git checkout -- .) — пути генерируются заново. Свои ручные правки
скиллов в user-режиме при обновлении потеряются.

Автозагрузка: скрипт настраивает автозагрузку трёх ключевых скиллов
(document-critic, ask-first, flash-pro-boost):
- ОБЁРТКА hermes (основной механизм): бинарь hermes в PATH заменяется
  скриптом, который добавляет -s ... при интерактивном запуске. REAL указывает
  на ЖИВОЙ оригинал (venv/bin/hermes — обновляется через hermes update), а не
  на копию; hermes.real — бэкап и fallback. Работает в любом shell, не зависит
  от .bashrc. Служебные подкоманды (gateway, cron, mcp, serve, update...) — без -s.
  Запись обёртки — через временный файл + mv (не cat > симлинк).
- HERMES_TUI_SKILLS=... в ~/.hermes/.env — для TUI-пути;
- alias hermes='hermes -s ...' в ~/.bashrc — фолбэк, только если обёртку
  поставить нельзя (нет прав на запись в каталог бинаря).
Повторный запуск идемпотентен: обёртка не перезаписывается, строки не дублируются.
В user-режиме локальные правки скиллов сохраняются через git stash (push → pull
→ pop), а не сбрасываются — потери данных нет.

Дедупликация: после клонирования скрипт проверяет коллизии имён SKILL.md (два
скилла с одинаковым name в frontmatter — резолвер Hermes при коллизии молча
пропускает скилл, прелоад не срабатывает). Сканируются ТОЛЬКО корневые скиллы
(root/<skill> или root/<cat>/<skill>) — .archive, references/templates/scripts и
вложенные каталоги внутри скиллов не трогаются. Untracked дубли (мусор установки/
копирования) перемещаются в ~/.hermes/.skill-trash/ (восстановимо, вне skills —
Hermes их не индексирует), канонический (tracked, из репо) сохраняется. Коллизии
внутри git-репо (оба tracked) не трогаются — выводят предупреждение.

Remote: после клонирования/обновления origin всегда ставится каноническим
(https://github.com/AllexandrKnife/<repo>.git) — токен не остаётся в .git/config,
лечатся битые URL от ручных правок. Креды берутся из ~/.git-credentials
(скрипт сохраняет токен туда с chmod 600, если github.com-строки нет).

