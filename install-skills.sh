#!/usr/bin/env bash
# install-skills.sh — установка всей инфраструктуры скиллов Hermes на новую машину.
#
# Источник: публичный репозиторий AllexandrKnife/hermes-skills-lib.
# Использование (одна команда):
#   curl -fsSL https://raw.githubusercontent.com/AllexandrKnife/hermes-skills-lib/main/install-skills.sh | bash
# или локально:
#   bash install-skills.sh [--base-dir DIR]
#     --base-dir DIR — префикс для путей установки (для тестирования в песочнице).
#
# Режимы (автоопределение, переопределяется через HERMES_INSTALL_MODE):
#   root (id -u == 0):  библиотеки -> /root/hermes-skills-lib, /root/hermes-triz-core, /root/eko-core, /root/hermes-soul
#   user (иначе):       библиотеки -> $HOME/hermes-skills-lib, $HOME/hermes-triz-core, $HOME/eko-core, $HOME/hermes-soul
#                       + sed-замена /root/... -> $HOME/... в скиллах (оркестраторы ссылаются
#                         на библиотеки абсолютными путями; в user-режиме пути переписываются).
#
# Устанавливает 5 репозиториев:
#   hermes-skills       -> ~/.hermes/skills          (активные скиллы, индексируются Hermes)
#   hermes-skills-lib   -> <lib_root>/hermes-skills-lib   (библиотека, публичный репо)
#   hermes-triz-core    -> <lib_root>/hermes-triz-core    (ТРИЗ-ядро)
#   eko-core            -> <lib_root>/eko-core            (ядро компетенций Устинова)
#   hermes-soul         -> <lib_root>/hermes-soul          (версионирование SOUL.md)
# 4 из 5 репозиториев приватные — нужен GitHub-токен (env GITHUB_TOKEN,
# ~/.git-credentials или интерактивный ввод). Сам скрипт секретов не содержит.
set -euo pipefail

# Версия скрипта (обновляется при значимых правках; выводится в отчёте —
# если после пуша выполняется старая версия, видно сразу, CDN-кэш).
SCRIPT_VERSION="2026-08-17+hermes-soul"

GITHUB_USER="AllexandrKnife"
BASE_DIR=""
TOKEN=""
MODE="${HERMES_INSTALL_MODE:-auto}"   # auto | root | user

# --- Парсинг аргументов -------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir)
      BASE_DIR="${2:?--base-dir требует аргумент}"
      shift 2
      ;;
    -h|--help)
      echo "Использование: install-skills.sh [--base-dir DIR]"
      echo "  --base-dir DIR — префикс путей установки (для тестов)."
      echo "  Режим: HERMES_INSTALL_MODE=auto|root|user (auto: root если id -u == 0)."
      exit 0
      ;;
    *)
      echo "Неизвестный аргумент: $1" >&2
      exit 2
      ;;
  esac
done

# --- Определение режима ----------------------------------------------------------
if [[ "$MODE" == "auto" ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then MODE="root"; else MODE="user"; fi
fi
case "$MODE" in
  root|user) ;;
  *) echo "Ошибка: HERMES_INSTALL_MODE должен быть auto|root|user (получено: $MODE)" >&2; exit 2 ;;
esac

# --- Целевые каталоги ----------------------------------------------------------
# lib_root: корень для трёх библиотек. В root-режиме — /root (пути зашиты в
# оркестраторах), в user-режиме — $HOME (пути будут переписаны sed ниже).
if [[ "$MODE" == "root" ]]; then
  LIB_ROOT="/root"
else
  LIB_ROOT="$HOME"
fi

if [[ -n "$BASE_DIR" ]]; then
  SKILLS_DIR="${BASE_DIR}/.hermes/skills"
  LIB_DIR="${BASE_DIR}/hermes-skills-lib"
  TRIZ_DIR="${BASE_DIR}/hermes-triz-core"
  EKO_DIR="${BASE_DIR}/eko-core"
  SOUL_DIR="${BASE_DIR}/hermes-soul"
else
  SKILLS_DIR="$HOME/.hermes/skills"
  LIB_DIR="${LIB_ROOT}/hermes-skills-lib"
  TRIZ_DIR="${LIB_ROOT}/hermes-triz-core"
  EKO_DIR="${LIB_ROOT}/eko-core"
  SOUL_DIR="${LIB_ROOT}/hermes-soul"
fi

# --- Токен ---------------------------------------------------------------------
get_token() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    TOKEN="$GITHUB_TOKEN"
  elif [[ -f "$HOME/.git-credentials" ]]; then
    # форматы: https://TOKEN@github.com  или  https://user:TOKEN@github.com
    # Только строка с github.com (в файле может быть несколько хостов/токенов).
    TOKEN="$(grep 'github.com' "$HOME/.git-credentials" 2>/dev/null | grep -oE '(ghp_|github_pat_)[A-Za-z0-9_]+' | head -1 || true)"
  fi
  if [[ -z "$TOKEN" ]]; then
    # При запуске через "curl ... | bash" stdin занят потоком из curl —
    # read из stdin вернёт EOF. Читаем с терминала напрямую (/dev/tty).
    if [[ -r /dev/tty ]]; then
      read -r -s -p "GitHub token (приватные репо): " TOKEN < /dev/tty
      echo
    fi
  fi
  if [[ -z "$TOKEN" ]]; then
    echo "Ошибка: токен не получен." >&2
    echo "Передайте его в команде (токен не попадёт в скрипт, только в окружение):" >&2
    echo "  curl -fsSL https://raw.githubusercontent.com/AllexandrKnife/hermes-skills-lib/main/install-skills.sh | GITHUB_TOKEN=<ваш-токен> bash" >&2
    echo "или положите его в ~/.git-credentials (формат: https://USER:TOKEN@github.com)." >&2
    echo "Где взять токен: GitHub → Settings → Developer settings → Personal access tokens." >&2
    exit 1
  fi
}

# --- Клонирование / обновление --------------------------------------------------
# clone_or_pull <repo> <dir> <use_token: yes|no>
# Три сценария:
#   1) каталог уже git-репо  -> git pull --ff-only (идемпотентность)
#   2) каталог непустой без .git (напр. ~/.hermes/skills после установки Hermes)
#      -> клонировать во временный каталог и скопировать содержимое (включая скрытые файлы)
#   3) пусто/нет каталога    -> git clone --depth 1
clone_or_pull() {
  local repo="$1" dir="$2" use_token="$3" url tmp stashed
  if [[ "$use_token" == "yes" ]]; then
    url="https://${GITHUB_USER}:${TOKEN}@github.com/${GITHUB_USER}/${repo}.git"
  else
    url="https://github.com/${GITHUB_USER}/${repo}.git"
  fi
  if [[ -d "$dir/.git" ]]; then
    echo "  $repo: уже установлен, обновляю (git pull)..."
    # В user-режиме пути в hermes-skills переписаны sed'ом -> перед pull сохранить
    # локальные правки в stash (в т.ч. sed-замены и ручные правки пользователя),
    # чтобы pull не упал на конфликте. После pull — вернуть stash.
    stashed="no"
    if [[ "$repo" == "hermes-skills" && "$MODE" == "user" ]] \
       && [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
      if git -C "$dir" stash push -m "install-skills $(date +%Y%m%d_%H%M%S)" --quiet; then
        stashed="yes"
      else
        echo "  $repo: ВНИМАНИЕ — не удалось сохранить локальные правки в stash" >&2
      fi
    fi
    git -C "$dir" pull --ff-only --quiet || {
      # Не фатально: пусть пользователь увидит, что pull не удался, но продолжит
      echo "  $repo: ВНИМАНИЕ — git pull не удался (сеть/конфликт), повторный запуск доделает" >&2
    }
    if [[ "$stashed" == "yes" ]]; then
      # stash pop может конфликтовать с новыми файлами из pull — правки НЕ теряются,
      # остаются в stash (git stash list). Это безопаснее, чем checkout -- . (потеря).
      if ! git -C "$dir" stash pop --quiet 2>/dev/null; then
        echo "  $repo: ВНИМАНИЕ — локальные правки остались в stash (git stash list), не потеряны" >&2
      fi
    fi
    if [[ "$repo" == "hermes-skills" && "$MODE" == "user" ]]; then
      fix_paths "$dir"
    fi
  elif [[ -d "$dir" ]] && [[ -n "$(ls -A "$dir" 2>/dev/null)" ]]; then
    echo "  $repo: каталог непустой (нет .git), клонирую через временный каталог..."
    tmp="$(mktemp -d)"
    git clone --depth 1 --quiet "$url" "$tmp/$repo"
    cp -a "$tmp/$repo/." "$dir/"
    rm -rf "$tmp"
    if [[ "$repo" == "hermes-skills" && "$MODE" == "user" ]]; then
      fix_paths "$dir"
    fi
  else
    echo "  $repo: клонирую (--depth 1)..."
    git clone --depth 1 --quiet "$url" "$dir"
    if [[ "$repo" == "hermes-skills" && "$MODE" == "user" ]]; then
      fix_paths "$dir"
    fi
  fi
  # КР-1 (17.08.2026): git сохраняет URL с токеном в .git/config после clone.
  # ВАЖНО: не парсить старый URL (были случаи: токен в URL, «двойной github.com»,
  # «github.com/https://github.com» от битых ручных чистк) — всегда ставить
  # канонический https://github.com/<user>/<repo>.git. Креды берутся из
  # ~/.git-credentials (credential.helper store). Идемпотентно.
  git -C "$dir" remote set-url origin "https://github.com/${GITHUB_USER}/${repo}.git"
}

# --- Переписывание путей оркестраторов (только user-режим) ----------------------
# Оркестраторы в hermes-skills ссылаются на библиотеки абсолютными путями /root/...
# В user-режиме библиотеки лежат в $HOME/... (или ${BASE_DIR}/... в песочнице)
# -> заменяем пути во всех .md файлах.
fix_paths() {
  local dir="$1" target n
  target="${BASE_DIR:-$LIB_ROOT}"
  n="$(grep -rlE '/root/(hermes-skills-lib|hermes-triz-core|eko-core|hermes-soul)' "$dir" --include="*.md" 2>/dev/null | wc -l || true)"
  if [[ "$n" -gt 0 ]]; then
    # -Z/-0: нуль-терминаторы — пути с пробелами/спецсимволами не разбиваются.
    # || true: pipefail + grep без совпадений = exit 1, что при set -e убило бы
    # скрипт на ПОВТОРНОМ запуске (пути уже переписаны) — баг 17.08.2026.
    grep -rlZE '/root/(hermes-skills-lib|hermes-triz-core|eko-core|hermes-soul)' "$dir" --include="*.md" 2>/dev/null \
      | xargs -0 sed -i \
          -e "s|/root/hermes-skills-lib|${target}/hermes-skills-lib|g" \
          -e "s|/root/hermes-triz-core|${target}/hermes-triz-core|g" \
          -e "s|/root/eko-core|${target}/eko-core|g" \
          -e "s|/root/hermes-soul|${target}/hermes-soul|g" || true
    echo "  hermes-skills: пути оркестраторов переписаны /root/... -> ${target}/... ($n файлов)"
  fi
}

# --- Дедупликация имён скиллов --------------------------------------------------
# Коллизия: два SKILL.md с одинаковым name в frontmatter. Резолвер Hermes при
# коллизии возвращает None (молча пропускает скилл) — прелоад не срабатывает
# (кейс flash-pro-boost 16.08.2026). Правило: канонический — tracked в git
# (из репо hermes-skills, в категории); untracked дубли (мусор установки/
# копирования) удаляются. Tracked-коллизии (оба в git — проблема репо)
# НЕ удаляются, выводят предупреждение.
dedupe_skill_names() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  command -v python3 >/dev/null 2>&1 || { echo "  дедупликация: python3 не найден, пропуск"; return 0; }
  python3 - "$dir" <<'PYEOF'
import os, re, sys, subprocess, time
root = sys.argv[1]
tracked = set()
git_ok = True
try:
    out = subprocess.run(["git", "-C", root, "ls-files"], capture_output=True, text=True, timeout=10)
    if out.returncode == 0:
        tracked = set(out.stdout.split())
    else:
        git_ok = False
except Exception:
    git_ok = False
if not git_ok:
    # Каталог не git-репо — сравнивать не с чем, все скиллы выглядят untracked.
    # Дедупликация отменяется (иначе можно удалить канонический). 
    print("  дедупликация: каталог не git-репо — пропущено")
    sys.exit(0)
names = {}
# Исключаемые каталоги: служебные (как EXCLUDED_SKILL_DIRS в Hermes) —
# .archive/.git/.github/.hub/.venv и т.п. + вложенные каталоги внутри скиллов.
EXCLUDED = {".git", ".github", ".hub", ".archive", ".venv", "venv", "node_modules",
            "references", "templates", "assets", "scripts"}
for dirpath, dirnames, filenames in os.walk(root):
    parts = dirpath.split(os.sep)
    if any(p in EXCLUDED for p in parts):
        dirnames[:] = []
        continue
    # Только корневые скиллы: root/<skill>/SKILL.md (depth 1) или
    # root/<cat>/<skill>/SKILL.md (depth 2). Вложенные SKILL.md внутри скилла
    # (depth 3+, напр. security/reverse-skill/browser-automation/SKILL.md) —
    # НЕ скиллы, пропуск.
    depth = len(parts) - len(root.split(os.sep))
    if depth > 2:
        dirnames[:] = []
        continue
    if "SKILL.md" in filenames:
        p = os.path.join(dirpath, "SKILL.md")
        rel = os.path.relpath(p, root)
        try:
            txt = open(p, encoding="utf-8", errors="replace").read(3000)
            m = re.search(r"^name:\s*(\S+)", txt, re.M)
            if m:
                names.setdefault(m.group(1), []).append((rel, rel in tracked))
        except Exception:
            continue
removed = 0
warned = 0
for nm, items in names.items():
    if len(items) < 2:
        continue
    tracked_items = [i for i in items if i[1]]
    if len(tracked_items) == len(items):
        # все в git — коллизия в репо, руками
        print(f"  дедупликация: КОЛЛИЗИЯ В РЕПО (не трогаю) {nm}: " + "; ".join(i[0] for i in items))
        warned += 1
        continue
    # канонический — tracked (в категории, из репо)
    keep = tracked_items[0][0] if tracked_items else max(items, key=lambda i: i[0].count("/"))[0]
    for rel, tr in items:
        if rel == keep:
            continue
        if tr:
            print(f"  дедупликация: tracked-дубль {nm}: {rel} (не трогаю)")
            warned += 1
            continue
        d = os.path.dirname(os.path.join(root, rel))
        # Безопасное удаление: переместить в .skill-trash ВНЕ skills-каталога
        # (в ~/.hermes/) вместо rmtree — если в дубле были пользовательские файлы/
        # чужой .git, их можно восстановить. ВАЖНО: корзина вне ~/.hermes/skills,
        # иначе Hermes просканирует её как скилл и коллизия вернётся (EXCLUDED_SKILL_DIRS
        # не содержит .trash — проверено 17.08.2026 по agent/skill_utils.py).
        trash = os.path.join(os.path.dirname(root), ".skill-trash")
        os.makedirs(trash, exist_ok=True)
        dest = os.path.join(trash, os.path.basename(d) + "-" + str(int(time.time())))
        os.rename(d, dest)
        print(f"  дедупликация: дубль {nm} перемещён в корзину: {rel}")
        removed += 1
print(f"  дедупликация: удалено {removed}, предупреждений {warned}" if removed or warned else "  дедупликация: коллизий не найдено")
PYEOF
}

# --- Автозагрузка ключевых скиллов ----------------------------------------------
# Три скилла (document-critic, ask-first, flash-pro-boost) должны грузиться в
# каждую сессию автоматически. Механизмы (см. hermes-skill-autoload):
#   1) ОБЁРТКА hermes (основной, железобетонный): заменяет бинарь hermes в PATH
#      скриптом, который добавляет -s document-critic,ask-first,flash-pro-boost
#      при интерактивном запуске. Работает в любом shell (bash/zsh/sh, login и
#      non-login, tmux, скрипты) — НЕ зависит от чтения .bashrc. Служебные
#      подкоманды (gateway, cron, mcp, serve, acp, update...) идут без -s.
#   2) HERMES_TUI_SKILLS в env-файле Hermes — для TUI-пути (там, где он используется);
#   3) alias hermes='hermes -s ...' в ~/.bashrc — фолбэк, только если обёртку
#      поставить нельзя (нет прав на запись в каталог бинаря).
# При --base-dir пишем только в песочницу (${BASE_DIR}/.hermes/.env, ${BASE_DIR}/.bashrc)
# и НЕ трогаем системный hermes — тест не должен ломать реальную машину.
WRAPPER_INSTALLED="no"

setup_wrapper() {
  local bin_path bin_dir real_path tmp_wrapper wrapper_real was_symlink
  if [[ -n "$BASE_DIR" ]]; then
    echo "  автозагрузка: обёртка пропущена (режим --base-dir, тест)"
    return 0
  fi
  bin_path="$(command -v hermes 2>/dev/null || true)"
  if [[ -z "$bin_path" ]]; then
    echo "  автозагрузка: hermes не найден в PATH — обёртка пропущена"
    return 0
  fi
  real_path="$(readlink -f "$bin_path")"
  bin_dir="$(dirname "$bin_path")"
  was_symlink="no"
  [[ -L "$bin_path" ]] && was_symlink="yes"

  # БАГ 16.08.2026 (исправлен): cat > симлинк пишет в ЦЕЛЬ симлинка (venv/bin/hermes),
  # а не заменяет симлинк. Обёртка оказывалась в цели, оригинал терялся, запуск падал
  # с "venv/bin/hermes.real: No such file". Самовосстановление: если цель симлинка уже
  # содержит нашу обёртку — вернуть оригинал из hermes.real и убрать симлинк.
  if [[ -L "$bin_path" ]] && grep -q "hermes-skills preload wrapper" "$real_path" 2>/dev/null; then
    if [[ -f "$bin_dir/hermes.real" ]]; then
      cp -a "$bin_dir/hermes.real" "$real_path"   # восстановить испорченную цель
      rm -f "$bin_path"                            # убрать симлинк
      was_symlink="yes"                            # оригинал остался в real_path
      echo "  автозагрузка: восстановлен оригинал hermes (симлинк-баг 16.08)"
    else
      echo "  автозагрузка: ОШИБКА — цель симлинка испорчена обёрткой, hermes.real не найден" >&2
      return 1
    fi
  fi

  if grep -q "hermes-skills preload wrapper" "$bin_path" 2>/dev/null; then
    echo "  автозагрузка: обёртка уже установлена ($bin_path)"
    WRAPPER_INSTALLED="yes"
    return 0
  fi
  if [[ ! -w "$bin_dir" ]]; then
    echo "  автозагрузка: нет прав на запись в $bin_dir — обёртка пропущена, использую alias"
    return 0
  fi
  cp -a "$real_path" "$bin_dir/hermes.real" || {
    echo "  автозагрузка: не удалось сохранить оригинал $real_path" >&2
    return 1
  }
  # REAL в обёртке — ЖИВОЙ оригинал, а не замороженная копия:
  #   - bin_path был симлинком (или симлинк-баг восстановлен) → оригинал остался в
  #     real_path (venv/bin/hermes) и обновляется через `hermes update` → REAL=real_path;
  #   - bin_path был файлом → оригинал только в hermes.real (копия) → REAL=hermes.real.
  # Fallback в обёртке: если REAL недоступен — переключиться на hermes.real.
  if [[ "$was_symlink" == "yes" ]]; then
    wrapper_real="$real_path"
  else
    wrapper_real="$bin_dir/hermes.real"
  fi
  # Запись через временный файл + mv: mv ЗАМЕНЯЕТ симлинк обычным файлом,
  # а не пишет сквозь него в цель (в отличие от cat > "$bin_path").
  tmp_wrapper="$(mktemp "$bin_dir/hermes.wrapper.XXXXXX")"
  cat > "$tmp_wrapper" <<WRAPPER
#!/usr/bin/env bash
# hermes-skills preload wrapper: добавляет -s document-critic,ask-first,flash-pro-boost
# для интерактивных сессий. Служебные подкоманды (gateway, cron, mcp, serve...) — без -s.
# REAL=${wrapper_real} (живой оригинал; обновляется через hermes update).
# Бэкап: hermes.real рядом с обёрткой (fallback, если REAL недоступен).
REAL="${wrapper_real}"
if [[ ! -x "\$REAL" ]]; then
  REAL="\$(dirname "\$(readlink -f "\$0")")/hermes.real"
fi
case "\$1" in
  gateway|cron|mcp|serve|acp|import|export|sessions|profile|completion|update|uninstall|version|help|--version|--help)
    exec "\$REAL" "\$@"
    ;;
esac
exec "\$REAL" -s document-critic,ask-first,flash-pro-boost "\$@"
WRAPPER
  chmod +x "$tmp_wrapper"
  mv -f "$tmp_wrapper" "$bin_path"
  WRAPPER_INSTALLED="yes"
  echo "  автозагрузка: обёртка установлена ($bin_path -> REAL=${wrapper_real})"
}

setup_autoload() {
  local target_env target_bashrc
  if [[ -n "$BASE_DIR" ]]; then
    target_env="${BASE_DIR}/.hermes/.env"
    target_bashrc="${BASE_DIR}/.bashrc"
  else
    target_env="$HOME/.hermes/.env"
    target_bashrc="$HOME/.bashrc"
  fi
  mkdir -p "$(dirname "$target_env")"

  if [[ ! -f "$target_env" ]] || ! grep -q "^HERMES_TUI_SKILLS=" "$target_env"; then
    printf 'HERMES_TUI_SKILLS=document-critic,ask-first,flash-pro-boost\n' >> "$target_env"
    echo "  автозагрузка: HERMES_TUI_SKILLS добавлена в $target_env"
  else
    echo "  автозагрузка: HERMES_TUI_SKILLS уже есть в $target_env"
  fi

  setup_wrapper

  # Если обёртка стоит — alias не нужен (двойной -s). Фолбэк — только без обёртки.
  if [[ "$WRAPPER_INSTALLED" == "yes" ]]; then
    if [[ -f "$target_bashrc" ]] && grep -q "^alias hermes=" "$target_bashrc"; then
      sed -i "/^alias hermes=.*document-critic.*/d" "$target_bashrc"
      echo "  автозагрузка: alias hermes убран из $target_bashrc (работает обёртка)"
    fi
  elif [[ ! -f "$target_bashrc" ]] || ! grep -q "^alias hermes=" "$target_bashrc"; then
    printf "alias hermes='hermes -s document-critic,ask-first,flash-pro-boost'\n" >> "$target_bashrc"
    echo "  автозагрузка: alias hermes добавлен в $target_bashrc"
  else
    echo "  автозагрузка: alias hermes уже есть в $target_bashrc"
  fi
}

# --- Основная логика ------------------------------------------------------------
# Pre-flight: обязательные команды, понятная ошибка вместо "command not found"
# на середине установки.
for _cmd in git curl python3; do
  if ! command -v "$_cmd" >/dev/null 2>&1; then
    echo "Ошибка: $_cmd не установлен. Установите его и повторите запуск." >&2
    exit 1
  fi
done

echo "Установка скиллов Hermes (пользователь GitHub: ${GITHUB_USER}, режим: ${MODE}, скрипт v${SCRIPT_VERSION})"
mkdir -p "$SKILLS_DIR" "$LIB_DIR" "$TRIZ_DIR" "$EKO_DIR"

# Токен нужен, если:
#   1) хотя бы одно приватное репо ещё не установлено (для clone), ИЛИ
#   2) в ~/.git-credentials нет github.com-строки (для pull приватных репо —
#      remote чист от токена, креды берутся из credentials).
NEED_TOKEN="no"
for d in "$SKILLS_DIR" "$TRIZ_DIR" "$EKO_DIR" "$SOUL_DIR"; do
  if [[ ! -d "$d/.git" ]]; then NEED_TOKEN="yes"; fi
done
if [[ "$NEED_TOKEN" == "no" ]] && { [[ ! -f "$HOME/.git-credentials" ]] || ! grep -q 'github.com' "$HOME/.git-credentials" 2>/dev/null; }; then
  NEED_TOKEN="yes"
fi
if [[ "$NEED_TOKEN" == "yes" ]]; then
  get_token
  # Сохранить токен в ~/.git-credentials (если github.com-строки ещё нет) —
  # иначе pull приватных репо после очистки remote запросит Username.
  if [[ -n "$TOKEN" ]]; then
    if [[ ! -f "$HOME/.git-credentials" ]] || ! grep -q 'github.com' "$HOME/.git-credentials" 2>/dev/null; then
      mkdir -p "$HOME"
      printf 'https://%s:%s@github.com\n' "$GITHUB_USER" "$TOKEN" >> "$HOME/.git-credentials"
      chmod 600 "$HOME/.git-credentials"
      git config --global credential.helper store 2>/dev/null || true
      echo "  credentials: токен сохранён в $HOME/.git-credentials (chmod 600)"
    fi
  fi
fi

echo "[1/7] hermes-skills -> $SKILLS_DIR"
clone_or_pull "hermes-skills" "$SKILLS_DIR" "yes"

echo "[2/7] hermes-skills-lib -> $LIB_DIR (публичный)"
clone_or_pull "hermes-skills-lib" "$LIB_DIR" "no"

echo "[3/7] hermes-triz-core -> $TRIZ_DIR"
clone_or_pull "hermes-triz-core" "$TRIZ_DIR" "yes"

echo "[4/7] eko-core -> $EKO_DIR"
clone_or_pull "eko-core" "$EKO_DIR" "yes"

echo "[5/7] hermes-soul -> $SOUL_DIR"
clone_or_pull "hermes-soul" "$SOUL_DIR" "yes"

echo "[6/7] дедупликация имён скиллов (коллизии блокируют прелоад)"
dedupe_skill_names "$SKILLS_DIR"

echo "[7/7] автозагрузка скиллов (document-critic, ask-first, flash-pro-boost)"
setup_autoload

# --- Отчёт -----------------------------------------------------------------------
echo
echo "=== Результат ==="
for entry in "hermes-skills:$SKILLS_DIR" "hermes-skills-lib:$LIB_DIR" "hermes-triz-core:$TRIZ_DIR" "eko-core:$EKO_DIR" "hermes-soul:$SOUL_DIR"; do
  name="${entry%%:*}"
  dir="${entry#*:}"
  hash="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo "N/A")"
  printf "  %-18s %s  %s\n" "$name" "$hash" "$dir"
done
echo "  скрипт: v${SCRIPT_VERSION} (если не последняя — CDN-кэш, повторите запуск)"
echo
echo "Готово. Перезапустите Hermes (новая сессия), чтобы скиллы подхватились.
Если установка прервалась (сеть/диск) — повторный запуск безопасен и доделает.
sudo hermes не использует прелоад — запускайте hermes без sudo."
