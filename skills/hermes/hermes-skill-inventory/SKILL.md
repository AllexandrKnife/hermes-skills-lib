---
name: hermes-skill-inventory
description: "Use when Инвентаризация скилов Hermes: кастомные vs"
critic_status: done
version: 1.0.0
tags: [hermes, skills, inventory, audit, usage-json, bundled-manifest, ssh]
---

# Hermes Skill Inventory — инвентаризация библиотеки скилов

## Когда использовать

- «какие скилы не стандартные / созданы агентом» на этой машине или на VPS
- Оценка зрелости библиотеки: живые vs заброшенные скилы, дубли, свежесозданные
- Перед переносом скилов между инстансами (что тащить, что оставить)
- Ревизия: что из накопленного реально используется

## Источники правды

Оба файла лежат в `~/.hermes/skills/` (на удалённом инстансе — там же):

| Файл | Формат | Что даёт |
|------|--------|----------|
| `.bundled_manifest` | строки `name:md5hash` | эталон стандартного набора скилов Hermes |
| `.usage.json` | dict name → meta | `created_by` (`agent` = создан агентом), `created_at`, `last_used_at`, `last_patched_at`, `archived_at` |

## Алгоритм (Python, работает локально и по SSH)

1. Собрать имена скилов: по всем `**/SKILL.md` извлечь `name:` из frontmatter
   (регэксп `^name:\s*(\S+)`), исключая `.archive`, `.curator_backups`, `.hub`.
2. Прочитать `.bundled_manifest`: `bundled = {line.split(":")[0] for line in f}`.
3. Скил **не в** bundled → кастомный/нестандартный (агентский, hub, сборный).
4. `created_by == "agent"` в `.usage.json` → создан агентом; `last_used_at`
   показывает живой скил или заброшен; `archived_at` не None → архивирован.
5. Для удалённого VPS — тот же скрипт по sshpass (см. ниже), вывод в stdout.

Готовый скрипт: `scripts/skilldiff.py` (на .format(), не f-string — безопасен для
ssh heredoc). Локально: `python3 <skill_dir>/scripts/skilldiff.py`; по SSH:
закинуть на VPS через heredoc и запустить.

**Формат вывода:** две секции — «НЕ СТАНДАРТНЫЕ (нет в bundled_manifest)»
с колонками name/created/by/путь и «ЕСТЬ В БАНДЛЕ, НО created_by=agent/patched»
(модифицированные бандловые).

## Удалённый инстанс (SSH)

```bash
sshpass -p '<pass>' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  -o UserKnownHostsFile=/dev/null root@<VPS> 'python3 /tmp/skilldiff.py'
```

Закинуть скрипт на VPS: `cat > /tmp/skilldiff.py << 'PYEOF' ... PYEOF` внутри
ssh-команды, затем запустить.

## Сверка перечня скиллов (маппинг «интерес/тема → скиллы»)

Когда собираешь перечень с привязкой (интересы пользователя → скиллы, тема → инструменты) —
проверять программно, не на глаз:

```python
r = terminal("find ~/.hermes/skills -name SKILL.md | sed 's|/SKILL.md||' | xargs -n1 basename | sort")
catalog = set(l.strip() for l in r["output"].splitlines() if l.strip())
missing = [(i, s) for i, grp in mapping.items() for s in grp if s not in catalog]  # несуществующие
dups = {k: v for k, v in Counter(flat).items() if v > 1}                            # задвоенные
assert sum(len(g) for g in mapping.values()) == len(set(flat))                      # суммы сходятся
```

База для каталога — имена директорий SKILL.md (basename), НЕ frontmatter `name:`:
быстрее и не зависит от парсинга. Классификацию по описаниям делать через
`skills_list` (description в выводе) или `skill_view`.

## Интерпретация результатов

- `created_by=agent` + недавний `last_used_at` — живой, обкатанный скил.
- `created_by=agent` + `last_used_at` пустой — свежесоздан, ещё не использован.
- Старые `created_at` (месяцы назад) + последнее использование только при массовой
  индексации — заброшен.
- Дубли: два скила с похожими именами/описаниями (напр. ioc-enrich и ioc-enrichment) —
  кандидаты на консолидацию.
- Сборные скилы (объединяющие несколько бандловых) — часто кастомные консолидации,
  проверять содержимое перед удалением.

## Pitfalls

- **f-string + ssh heredoc**: `python3 -c "..."` с вложенными кавычками и f-string
  с `\"` внутри даёт `SyntaxError: f-string expression part cannot include a backslash`.
  Писать скрипт через `cat > /tmp/x.py << 'PYEOF'` (одинарные кавычки у heredoc —
  без интерполяции), потом `python3 /tmp/x.py`.
- find по `**/SKILL.md` подхватывает архивы и бэкапы — всегда фильтровать
  `.archive`, `.curator_backups`, `.hub`.
- В `.bundled_manifest` строки `name:hash` — резать по первому `:`, не по всем.
- `.usage.json` может содержать скилы, которых уже нет на диске (и наоборот) —
  пересекать по именам, не доверять одному файлу.
- Оценку «что пригодится пользователю» делать под его профиль работы (аудит смет,
  OSINT контрагентов), не по общему «интересно» — иначе выбор не сойдётся с реальностью.
- **Имя скилла ≠ назначение.** kitesurf-* звучит как спорт (кайтсёрфинг), на деле — MCP-инструмент
  веб-скраппинга (click/fill/navigate). Найденный баг 08.2026: в перечне интересов создана группа
  «Кайтсёрфинг» по одному имени, пользователь поправил. Классифицировать по описанию
  (skills_list/skill_view), интересы пользователя брать из памяти, не выводить из названий скиллов.
- find по `**/SKILL.md` возвращает пути с категорией (`analytics/имя`) — для сверки имён с каталогом
  брать basename директории (`xargs -n1 basename`), иначе каждый скилл с категорией ложно уйдёт
  в «отсутствует в каталоге» (первый прогон 08.2026: «пропали» все скиллы с категорией в пути,
  не нашлись только бескатегорийные ask-first/karpathy-guidelines/deadend-detector/triz-40-principles).

## Принудительная загрузка скилов (прелоад)

Как сделать так, чтобы скилл грузился в каждую интерактивную сессию автоматически —
`HERMES_TUI_SKILLS` в `~/.hermes/.env` (механизм, ограничения, проверка) — см.
`references/skill-preloading.md`. Прелоад детерминирован, в отличие от вероятностной
авто-загрузки по описанию.

## Связанные скиллы

- skill-audit — аудит КАЧЕСТВА SKILL.md (ссылки, пути, команды); inventory — аудит
  СОСТАВА библиотеки. Не дублировать: для content-проверки — skill-audit.
