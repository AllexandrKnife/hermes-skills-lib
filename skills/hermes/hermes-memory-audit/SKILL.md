---
name: hermes-memory-audit
description: "Use when Аудит памяти Hermes по 8 уровням: модель,"
critic_status: done
version: 1.0.0
---

# Hermes Memory Audit — аудит памяти по 8 уровням

## Когда использовать

- «опиши организацию своей памяти», «проведи аудит памяти», «что хранится в памяти»
- Ревизия перед консолидацией MEMORY.md/USER.md, чисткой /root, проверкой cron-бэкфилла
- Диагностика «память не пишется» / «бэкфилл не работает»

## Модель 8 уровней (канон для этого пользователя)

| Ур. | Уровень | Где живёт | Инжекция |
|-----|---------|-----------|----------|
| 0 | Рабочая память (контекст сессии) | окно сессии | всегда, компрессия |
| 1 | Identity | ~/.hermes/SOUL.md | всегда |
| 2 | Постоянная семантика | ~/.hermes/memories/MEMORY.md + USER.md | всегда, лимиты 3000/2000 |
| 3 | Процедурная (скиллы) | ~/.hermes/skills/ | по требованию (skill_view) |
| 4 | Эпизодическая | ~/.hermes/state.db (SQLite+FTS5) | по запросу (session_search) |
| 5 | Файловая | /root, ~/.hermes/plans/ | по пути |
| 6 | Автономная (cron) | ~/.hermes/cron/jobs.json + executions.db | своя сессия на тик |
| 7 | Внешняя (ruflo MCP) | /root/.swarm/memory.db + agentdb-memory.db | по требованию (mcp__ruflo__*) |
| 8 | Вспомогательные БД | kanban.db, verification_evidence.db | подсистемами |

## Процедура аудита (read-only, ничего не менять без запроса)

Уровень 2:
```
stat -c '%y %n' ~/.hermes/memories/*.md
```
Проверить заполненность лимитов: MEMORY.md 3000 chars, USER.md 2000. Порог тревоги 90% — следующая запись вытеснит живые факты.

Уровень 3:
```
find ~/.hermes/skills -name "SKILL.md" | wc -l
grep -rL "critic_status" ~/.hermes/skills --include="SKILL.md"   # обход gate
grep -rl "SKILL_PRUNED" ~/.hermes/skills --include="SKILL.md" | wc -l
find ~/.hermes/skills -name "SKILL.md" -printf '%T@ %p\n' | sort -n | head -5  # старые
```

Уровень 4:
```
python3 -c "import sqlite3; c=sqlite3.connect('/root/.hermes/state.db'); print(c.execute('SELECT COUNT(*) FROM sessions').fetchone(), c.execute('SELECT COUNT(*) FROM messages').fetchone())"
```
FTS5: 12 таблиц на 1 индекс = норма (messages_fts + trigram, по 6 служебных). Мусор: request_dump_*.json в ~/.hermes/sessions/ (служебные дампы запросов).

Уровень 6 — КРИТИЧЕСКИЙ ПРОВЕРЯЕМЫЙ: enabled в jobs.json ≠ работает. Правду говорит только executions.db:
```
python3 -c "
import sqlite3
c = sqlite3.connect('/root/.hermes/cron/executions.db')
for r in c.execute('SELECT job_id, source, status, claimed_at, finished_at FROM executions ORDER BY rowid DESC LIMIT 5'): print(r)"
```
- source='direct' = ручной запуск (cronjob action=run), НЕ тик по расписанию
- Ноль строк за N дней при enabled=true = джоб мёртв (не стартует или падает до скрипта)

Уровень 7 — ДВЕ БД ruflo, смотреть обе:
```
python3 -c "
import sqlite3
for db in ['/root/.swarm/memory.db','/root/.swarm/agentdb-memory.db']:
    c=sqlite3.connect(db); print(db)
    for r in c.execute('SELECT namespace,key,length(content),updated_at FROM memory_entries ORDER BY updated_at DESC'): print(r)"
```
- memory.db (CLI `ruflo memory store`) — старая sql.js, но содержит полную AgentDB-схему (episodes, reasoning_patterns, causal_edges, vector_indexes — реально заполнены)
- agentdb-memory.db (MCP `mcp__ruflo__memory_store`) — новая AgentDB
- Слепое пятно: `mcp__ruflo__memory_stats` видит ТОЛЬКО agentdb-memory.db (19 записей), старую БД (69) — только CLI/SQL. Единого окна нет.
- Дубли кейсов: один кейс в обеих БД под разными именами (case-site-margin == case-anomalnye-bs)
- Мусор: тестовая запись case-probe
- sqlite3 CLI в WSL отсутствует — использовать python3 sqlite3

Уровень 5:
```
du -sh /root/*/ | sort -rh | head -15
ls ~/.hermes/plans/
```
Типовой мусор: node_modules без package.json в /root (артефакт установки, сотни MB), browser-use-env, far2l.

Уровень 8: kanban.db пуст (подсистема не используется — норма), verification_evidence.db заполнен (работает).

## Формат отчёта

- По уровням: статус ОК / ВНИМАНИЕ / КР + цифры с диска (никаких «по памяти»)
- В конце — конкретные действия с приоритетом и оценкой времени (слой 8 применимости)
- Отчёт — результат к выдаче → прогнать document-critic ДО выдачи (слои 1-3 минимум: арифметика, источники, противоречия), маркер «Критика: пройдена» в конце

## Pitfalls

- НЕ чинить ничего в ходе аудита без запроса пользователя — только рекомендации
- НЕ верить jobs.json enabled=true — проверять executions.db
- НЕ делать вывод «бэкфилл работает» по свежим записям в ruflo: записи могли быть сделаны вручную
- НЕ путать две БД ruflo при подсчёте записей
- `ruflo mcp status` показывает транзиентный PID, не сервер — реальный процесс `ps aux | grep ruflo`

## References

- references/audit-2026-08-07.md — снапшот первого полного аудита (состояние, находки, follow-up)
