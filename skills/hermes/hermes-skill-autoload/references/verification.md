# Верификация прелоада скилла — точные команды

Проверено 2026-08-03 на WSL (hermes в /usr/local/lib/hermes-agent, state.db в ~/.hermes/).

## 1. Строка в env-файле

```bash
grep "^HERMES_TUI_SKILLS=" /root/.hermes/.env
stat -c '%y' /root/.hermes/.env   # время записи — сравнить со стартом сессии
```

## 2. Маркер прелоада в системном промпте сессии (главный сигнал)

state.db — SQLite-хранилище сообщений/сессий (~262MB, активно обновляется).

```python
import sqlite3
con = sqlite3.connect('/root/.hermes/state.db')
cur = con.cursor()
# последние сессии: id, source, started_at (epoch), title
cur.execute("SELECT id, source, started_at, title FROM sessions ORDER BY started_at DESC LIMIT 4")
for r in cur.fetchall(): print(r)
# системный промпт сессии — ищем маркер preload
cur.execute("SELECT system_prompt FROM sessions WHERE id='<SESSION_ID>'")
sp = cur.fetchone()[0]
print('preloaded' in sp.lower())   # True = прелоад сработал
```

Схема: `sessions(id, source, user_id, model, system_prompt, started_at, ...)`, `messages(session_id, role, content, ...)`.

ВАЖНО: `'document-critic' in sp` — НЕ сигнал. Имя скилла есть в общем индексе available_skills у любой сессии. Сигнал — только строка `preloaded` / `IMPORTANT: The user launched this CLI session with the "X" skill preloaded`.

## 3. Телеметрия curator (.usage.json)

```bash
python3 -c "
import json
d=json.load(open('/root/.hermes/skills/.usage.json'))
for k,v in d.items():
    if 'critic' in k.lower(): print(k, v['last_used_at'], v['use_count'])
"
```

- Прелоад вызывает `bump_use()` → last_used_at = время старта сессии.
- НО `skill_view` тоже бьёт usage (last_viewed_at == last_used_at). Однозначный вывод только при сравнении с `sessions.started_at`: прелоад даёт bump РОВНО на старте, ручной просмотр — в момент вызова.
- `created_by: null` в .usage.json = user-owned скилл (curator его не трогает, патчи откажет).

## 4. Окружение процесса (есть ли переменная)

Терминал-бэкенд (rtk) снимает снапшот env родительского процесса в /tmp/hermes-snap-<hash>.sh:

```bash
grep -h "HERMES_TUI_SKILLS" /tmp/hermes-snap-*.sh   # переменная в env процесса = процесс перезапущен ПОСЛЕ записи
stat -c '%y' /tmp/hermes-snap-*.sh                  # свежий снапшот (сегодняшний) — актуальное состояние
```

Старые снапшоты (другие даты) неинформативны — смотрят только свежий, созданный текущей командой.

## 5. Ключевые точки исходников (для справки)

- `hermes_cli/main.py:697` — `load_hermes_dotenv()` — env-файл читается один раз при старте процесса
- `hermes_cli/main.py:2359` — `-s/--skills` транслируется в `HERMES_TUI_SKILLS` для TUI-процесса
- `tui_gateway/server.py:5772` — `_parse_tui_skills_env()` читает переменную
- `tui_gateway/server.py:6194-6198` — вызов `build_preloaded_skills_prompt()` при старте сессии
- `agent/skill_commands.py:747` — функция прелоада, маркер «IMPORTANT ... preloaded», `bump_use()`

## Типовой сценарий «не подхватилось» (из практики)

env-файл записан в 22:08, сессия стартовала 21:56 → переменной в процессе нет.
Процесс перезапущен (в снапшоте переменная есть), но сессия резюмнута → маркер в system_prompt отсутствует, bump_use не свежий.
Решение: полный выход, запуск, `/new`. После этого оба сигнала (маркер + bump) появляются.
