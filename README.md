# hermes-skills-lib — библиотека доменных скиллов (вариант В)

Вынесенные из ~/.hermes/skills доменные скиллы: в Hermes остаются только
оркестраторы (network-infra, hermes-agent, osint, github-workflow, academic,
smeta-audit), которые по таблице триггеров читают SKILL.md из этого репо.

Структура: skills/<категория>/<имя>/SKILL.md (+ supporting files).
Оркестраторы в ~/.hermes/skills ссылаются на пути здесь.

Категории: network/ (сеть/VPN/роутеры/VPS/WSL), hermes/ (администрирование
Hermes), osint/ (разведка), github/, academic/, construction/ (сметы).
