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

Скрипт клонирует/обновляет 4 репозитория:
- hermes-skills → ~/.hermes/skills (активные скиллы)
- hermes-skills-lib → /root/hermes-skills-lib
- hermes-triz-core → /root/hermes-triz-core
- eko-core → /root/eko-core

Токен берётся из env GITHUB_TOKEN, ~/.git-credentials или интерактивного ввода.
Идемпотентен: повторный запуск делает git pull. --base-dir — для песочницы.

Режимы (автоопределение):
- root (id -u == 0): библиотеки в /root/... — пути оркестраторов совпадают.
- user: библиотеки в $HOME/... — скрипт переписывает /root/... → $HOME/...
  во всех .md файлах hermes-skills (sed), иначе оркестраторы не найдут библиотеки.

Внимание (user-режим): перед обновлением hermes-skills локальные правки скиллов
сбрасываются (git checkout -- .) — пути генерируются заново. Свои ручные правки
скиллов в user-режиме при обновлении потеряются.

Автозагрузка: скрипт дополнительно настраивает автозагрузку трёх ключевых
скиллов (document-critic, ask-first, flash-pro-boost):
- HERMES_TUI_SKILLS=... в ~/.hermes/.env — для TUI-сессий;
- alias hermes='hermes -s ...' в ~/.bashrc — для CLI-сессий (CLI env-переменную
  не читает, только флаг -s). Повторный запуск не дублирует строки.

