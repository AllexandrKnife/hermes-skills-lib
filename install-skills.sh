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
#   root (id -u == 0):  библиотеки -> /root/hermes-skills-lib, /root/hermes-triz-core, /root/eko-core
#   user (иначе):       библиотеки -> $HOME/hermes-skills-lib, $HOME/hermes-triz-core, $HOME/eko-core
#                       + sed-замена /root/... -> $HOME/... в скиллах (оркестраторы ссылаются
#                         на библиотеки абсолютными путями; в user-режиме пути переписываются).
#
# Устанавливает 4 репозитория:
#   hermes-skills       -> ~/.hermes/skills          (активные скиллы, индексируются Hermes)
#   hermes-skills-lib   -> <lib_root>/hermes-skills-lib   (библиотека, публичный репо)
#   hermes-triz-core    -> <lib_root>/hermes-triz-core    (ТРИЗ-ядро)
#   eko-core            -> <lib_root>/eko-core            (ядро компетенций Устинова)
# 3 из 4 репозиториев приватные — нужен GitHub-токен (env GITHUB_TOKEN,
# ~/.git-credentials или интерактивный ввод). Сам скрипт секретов не содержит.
set -euo pipefail

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
      echo "  Режим: HERES_INSTALL_MODE=auto|root|user (auto: root если id -u == 0)."
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
else
  SKILLS_DIR="$HOME/.hermes/skills"
  LIB_DIR="${LIB_ROOT}/hermes-skills-lib"
  TRIZ_DIR="${LIB_ROOT}/hermes-triz-core"
  EKO_DIR="${LIB_ROOT}/eko-core"
fi

# --- Токен ---------------------------------------------------------------------
get_token() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    TOKEN="$GITHUB_TOKEN"
  elif [[ -f "$HOME/.git-credentials" ]]; then
    # форматы: https://TOKEN@github.com  или  https://user:TOKEN@github.com
    TOKEN="$(grep -oE '(ghp_|github_pat_)[A-Za-z0-9_]+' "$HOME/.git-credentials" 2>/dev/null | head -1 || true)"
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
  local repo="$1" dir="$2" use_token="$3" url tmp
  if [[ "$use_token" == "yes" ]]; then
    url="https://${GITHUB_USER}:${TOKEN}@github.com/${GITHUB_USER}/${repo}.git"
  else
    url="https://github.com/${GITHUB_USER}/${repo}.git"
  fi
  if [[ -d "$dir/.git" ]]; then
    echo "  $repo: уже установлен, обновляю (git pull)..."
    # В user-режиме пути в hermes-skills переписаны sed'ом -> перед pull сбросить
    # локальные правки, чтобы pull не упал на конфликте, потом применить sed заново.
    if [[ "$repo" == "hermes-skills" && "$MODE" == "user" ]]; then
      git -C "$dir" checkout -- . 2>/dev/null || true
    fi
    git -C "$dir" pull --ff-only --quiet
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
}

# --- Переписывание путей оркестраторов (только user-режим) ----------------------
# Оркестраторы в hermes-skills ссылаются на библиотеки абсолютными путями /root/...
# В user-режиме библиотеки лежат в $HOME/... (или ${BASE_DIR}/... в песочнице)
# -> заменяем пути во всех .md файлах.
fix_paths() {
  local dir="$1" target n
  target="${BASE_DIR:-$LIB_ROOT}"
  n="$(grep -rlE '/root/(hermes-skills-lib|hermes-triz-core|eko-core)' "$dir" --include="*.md" 2>/dev/null | wc -l)"
  if [[ "$n" -gt 0 ]]; then
    grep -rlE '/root/(hermes-skills-lib|hermes-triz-core|eko-core)' "$dir" --include="*.md" 2>/dev/null \
      | xargs sed -i \
          -e "s|/root/hermes-skills-lib|${target}/hermes-skills-lib|g" \
          -e "s|/root/hermes-triz-core|${target}/hermes-triz-core|g" \
          -e "s|/root/eko-core|${target}/eko-core|g"
    echo "  hermes-skills: пути оркестраторов переписаны /root/... -> ${target}/... ($n файлов)"
  fi
}

# --- Автозагрузка ключевых скиллов ----------------------------------------------
# Три скилла (document-critic, ask-first, flash-pro-boost) должны грузиться в
# каждую сессию автоматически. Два механизма (см. hermes-skill-autoload):
#   1) HERMES_TUI_SKILLS в env-файле Hermes — читается TUI-путём при старте;
#   2) alias hermes='hermes -s ...' в ~/.bashrc — для CLI-пути (CLI env-переменную
#      НЕ читает, только флаг -s; alias подставляет флаг при каждом запуске).
# При --base-dir пишем в песочницу (${BASE_DIR}/.hermes/.env, ${BASE_DIR}/.bashrc),
# чтобы тест не трогал реальный конфиг.
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

  if [[ ! -f "$target_bashrc" ]] || ! grep -q "^alias hermes=" "$target_bashrc"; then
    printf "alias hermes='hermes -s document-critic,ask-first,flash-pro-boost'\n" >> "$target_bashrc"
    echo "  автозагрузка: alias hermes добавлен в $target_bashrc"
  else
    echo "  автозагрузка: alias hermes уже есть в $target_bashrc"
  fi
}

# --- Основная логика ------------------------------------------------------------
echo "Установка скиллов Hermes (пользователь GitHub: ${GITHUB_USER}, режим: ${MODE})"
mkdir -p "$SKILLS_DIR" "$LIB_DIR" "$TRIZ_DIR" "$EKO_DIR"

# Токен нужен, только если хотя бы одно приватное репо ещё не установлено.
NEED_TOKEN="no"
for d in "$SKILLS_DIR" "$TRIZ_DIR" "$EKO_DIR"; do
  if [[ ! -d "$d/.git" ]]; then NEED_TOKEN="yes"; fi
done
if [[ "$NEED_TOKEN" == "yes" ]]; then
  get_token
fi

echo "[1/5] hermes-skills -> $SKILLS_DIR"
clone_or_pull "hermes-skills" "$SKILLS_DIR" "yes"

echo "[2/5] hermes-skills-lib -> $LIB_DIR (публичный)"
clone_or_pull "hermes-skills-lib" "$LIB_DIR" "no"

echo "[3/5] hermes-triz-core -> $TRIZ_DIR"
clone_or_pull "hermes-triz-core" "$TRIZ_DIR" "yes"

echo "[4/5] eko-core -> $EKO_DIR"
clone_or_pull "eko-core" "$EKO_DIR" "yes"

echo "[5/5] автозагрузка скиллов (document-critic, ask-first, flash-pro-boost)"
setup_autoload

# --- Отчёт -----------------------------------------------------------------------
echo
echo "=== Результат ==="
for entry in "hermes-skills:$SKILLS_DIR" "hermes-skills-lib:$LIB_DIR" "hermes-triz-core:$TRIZ_DIR" "eko-core:$EKO_DIR"; do
  name="${entry%%:*}"
  dir="${entry#*:}"
  hash="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo "N/A")"
  printf "  %-18s %s  %s\n" "$name" "$hash" "$dir"
done
echo
echo "Готово. Перезапустите Hermes (новая сессия), чтобы скиллы подхватились."
