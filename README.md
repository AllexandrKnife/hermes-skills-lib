# hermes-skills-lib — библиотека доменных скиллов (вариант В)

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

