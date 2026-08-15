# Перенос скиллов Hermes между WSL-образами одной машины

Проверено дважды 12.08.2026:
- Прогон 1: Ubuntu-22.04-D (источник, root) → Ubuntu-22.04 (цель, user), Hermes v0.20.0 в обоих, цель уже имела 189 скиллов, перенесено 177 (1.9M tar.gz, 1165 файлов).
- Прогон 2: Ubuntu-22.04-flash (источник, root) → Ubuntu-24.04 (цель, user), цель имела 80 скиллов, перенесено 203 каталога (2.7M tar.gz, 1366 файлов) → 283 всего. Набор образов на хосте к этому моменту изменился (Ubuntu-22.04-D/-22.04 уже не было) — цель брать по факту `wsl.exe -l -v`, не по прошлому reference.

## 0. Определить, какой образ — «я»

При нескольких запущенных дистрибутивах (`wsl.exe -l -v` показывает все) ошибка «проверил не тот образ» реальна:

```bash
wsl.exe -l -v   # NAME + STATE: все запущенные
# в каждом кандидате:
wsl.exe -d <distro> -u root -e bash -c "ps aux | grep hermes | grep -v grep"
```

Свой образ опознаётся по процессу hermes с ТЕМИ ЖЕ прелоаженными скиллами, что в текущей сессии: `hermes -s document-critic,ask-first,flash-pro-boost`. Совпадение списка `-s` = это ты.

## 1. Разведка цели

```bash
# Версия, наличие конфига, скиллы, провайдер:
wsl.exe -d <target> -u <user> -e bash -c "
  /home/<user>/.local/bin/hermes --version | head -3
  find /home/<user>/.hermes/skills -name SKILL.md | wc -l
  ls /home/<user>/.hermes/memories/
  grep -A3 'provider' /home/<user>/.hermes/config.yaml | head"
```

- Версия должна совпадать с источником (иначе сначала обновить цель).
- У цели МОГУТ быть свои memories/skills — не перезаписывать без запроса.
- Сеть цели: `curl -s -o /dev/null -w '%{http_code}' https://api.deepseek.com` — 401 = сеть ок (401 без ключа — норма).

## 2. Diff скиллов

```bash
# оба списка в файлы, потом Python:
find /root/.hermes/skills -name SKILL.md | sed 's|/root/.hermes/skills/||' | sort > /tmp/mine.txt
wsl.exe -d <target> -u <user> -e bash -c "find /home/<user>/.hermes/skills -name SKILL.md" \
  | tr -d '\0\r' | sed 's|/home/<user>/.hermes/skills/||' | sort > /tmp/target.txt
```

```python
mine = set(l.strip() for l in open('/tmp/mine.txt'))
target = set(l.strip() for l in open('/tmp/target.txt'))
missing = sorted(m for m in mine - target if '.archive' not in m)
dirs = sorted(set(m.rsplit('/SKILL.md', 1)[0] for m in missing))
open('/tmp/missing_dirs.txt', 'w').write('\n'.join(dirs))
```

Не забыть исключить `.archive/` (архивные скиллы). Переносить каталоги целиком — скиллы содержат references/scripts/assets.

## 3. Упаковка и доставка

```bash
tar -czf /tmp/skills_missing.tar.gz -C /root/.hermes/skills $(tr '\n' ' ' < /tmp/missing_dirs.txt)
```

**НЕ пайпить в wsl.exe** — бинарный stdin режется UTF-8 фильтром:
`cat arc | wsl.exe ... tar xzf -` → `stream did not contain valid UTF-8` / `gzip: unexpected end of file`.

Правильно — через общую папку Windows (drvfs читается любым образом), НО ТОЛЬКО на не-корпоративных машинах (на корп. ноуте Public запрещён 08.2026: DLP/видимость; текстовые скрипты — через stdin, бинарное — согласовать канал):

```bash
cp /tmp/skills_missing.tar.gz /mnt/c/Users/Public/
wsl.exe -d <target> -u <user> -e bash -c \
  "tar xzf /mnt/c/Users/Public/skills_missing.tar.gz -C /home/<user>/.hermes/skills \
   && rm -f /mnt/c/Users/Public/skills_missing.tar.gz && echo EXTRACT-OK" | tr -d '\0'
```

Распаковывать от владельца целевого профиля (tar сохранит его владельца в файлах). /mnt/c/Users/Public — общедоступная папка Windows, не требует прав пользователя.

## 4. Верификация

```bash
# количество = старое + перенесённое (пересчитать, 189+177=366):
wsl.exe -d <target> -u <user> -e bash -c "find /home/<user>/.hermes/skills -name SKILL.md | wc -l"
# sha256 ключевых против оригиналов (должны совпасть 1:1):
wsl.exe -d <target> -u <user> -e sha256sum \
  /home/<user>/.hermes/skills/productivity/document-critic/SKILL.md \
  /home/<user>/.hermes/skills/ask-first/SKILL.md \
  /home/<user>/.hermes/skills/software-development/flash-pro-boost/SKILL.md
sha256sum /root/.hermes/skills/productivity/document-critic/SKILL.md \
  /root/.hermes/skills/ask-first/SKILL.md \
  /root/.hermes/skills/software-development/flash-pro-boost/SKILL.md
# владелец файлов:
wsl.exe -d <target> -u <user> -e ls -ld /home/<user>/.hermes/skills/productivity/document-critic
```

Проверено 12.08.2026 (прогон 2): первый замер дал 282 вместо 283 — повторный find подтвердил 283 (80+203). Единичное расхождение счёта = пересчитать, не принимать первое число. Для set-сравнения приводить оба множества к одному формату (пути с `/SKILL.md`): сравнение каталогов (без `/SKILL.md`) со списком файлов даёт ложные «expected but NOT present». Безобидная строка `wsl: Failed to translate '\wsl.localhost\...'` в выводе wsl.exe — не ошибка, это перевод cwd источника.

## 5. Автозагрузка (идемпотентно)

.env защищён от write_file/patch — только terminal, от владельца профиля:

```bash
wsl.exe -d <target> -u <user> -e bash -c "
  grep -q '^HERMES_TUI_SKILLS=' /home/<user>/.hermes/.env \
    && echo EXISTS \
    || echo 'HERMES_TUI_SKILLS=document-critic,ask-first,flash-pro-boost' >> /home/<user>/.hermes/.env
  grep '^HERMES_TUI_SKILLS=' /home/<user>/.hermes/.env"
```

CLI-нюанс: HERMES_TUI_SKILLS читается только TUI-запусками. Для CLI — `hermes -s document-critic,ask-first,flash-pro-boost` или алиас в .bashrc.

## Итог по объёму

- Скиллы источника: 88M / 271 SKILL.md (с references/scripts).
- Отсутствовало в цели: 177 каталогов → tar.gz 1.9M (1165 файлов). Для C: с 12G свободно — ничто.
- Полное окружение (root + venv) — 13.4G: НЕ переносить, если не просили; сначала скиллы.
