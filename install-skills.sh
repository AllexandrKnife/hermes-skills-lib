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
# Устанавливает 4 репозитория:
#   hermes-skills       -> ~/.hermes/skills          (активные скиллы, индексируются Hermes)
#   hermes-skills-lib   -> /root/hermes-skills-lib   (библиотека, публичный репо)
#   hermes-triz-core    -> /root/hermes-triz-core    (ТРИЗ-ядро)
#   eko-core            -> /root/eko-core            (ядро компетенций Устинова)
# 3 из 4 репозиториев приватные — нужен GitHub-токен (env GITHUB_TOKEN,
# ~/.git-credentials или интерактивный ввод). Сам скрипт секретов не содержит.
set -euo pipefail

GITHUB_USER="AllexandrKnife"
BASE_DIR=""
TOKEN=""

# --- Парсинг аргументов -------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir)
      BASE_DIR="${2:?--base-dir требует аргумент}"
      shift 2
      ;;
    -h|--help)
      echo "Использование: install-skills.sh [--base-dir DIR]"
      echo "  --base-dir DIR — префикс путей установки (по умолчанию: ~/.hermes/skills, /root/...)"
      exit 0
      ;;
    *)
      echo "Неизвестный аргумент: $1" >&2
      exit 2
      ;;
  esac
done

# --- Целевые каталоги ----------------------------------------------------------
if [[ -n "$BASE_DIR" ]]; then
  SKILLS_DIR="${BASE_DIR}/root/.hermes/skills"
  LIB_DIR="${BASE_DIR}/root/hermes-skills-lib"
  TRIZ_DIR="${BASE_DIR}/root/hermes-triz-core"
  EKO_DIR="${BASE_DIR}/root/eko-core"
else
  SKILLS_DIR="$HOME/.hermes/skills"
  LIB_DIR="/root/hermes-skills-lib"
  TRIZ_DIR="/root/hermes-triz-core"
  EKO_DIR="/root/eko-core"
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
    read -r -s -p "GitHub token (приватные репо): " TOKEN
    echo
  fi
  if [[ -z "$TOKEN" ]]; then
    echo "Ошибка: токен не получен. Задайте GITHUB_TOKEN или ~/.git-credentials." >&2
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
    git -C "$dir" pull --ff-only --quiet
  elif [[ -d "$dir" ]] && [[ -n "$(ls -A "$dir" 2>/dev/null)" ]]; then
    echo "  $repo: каталог непустой (нет .git), клонирую через временный каталог..."
    tmp="$(mktemp -d)"
    git clone --depth 1 --quiet "$url" "$tmp/$repo"
    cp -a "$tmp/$repo/." "$dir/"
    rm -rf "$tmp"
  else
    echo "  $repo: клонирую (--depth 1)..."
    git clone --depth 1 --quiet "$url" "$dir"
  fi
}

# --- Основная логика ------------------------------------------------------------
echo "Установка скиллов Hermes (пользователь GitHub: ${GITHUB_USER})"
mkdir -p "$SKILLS_DIR" "$LIB_DIR" "$TRIZ_DIR" "$EKO_DIR"

# Токен нужен, только если хотя бы одно приватное репо ещё не установлено.
NEED_TOKEN="no"
for d in "$SKILLS_DIR" "$TRIZ_DIR" "$EKO_DIR"; do
  if [[ ! -d "$d/.git" ]]; then NEED_TOKEN="yes"; fi
done
if [[ "$NEED_TOKEN" == "yes" ]]; then
  get_token
fi

echo "[1/4] hermes-skills -> $SKILLS_DIR"
clone_or_pull "hermes-skills" "$SKILLS_DIR" "yes"

echo "[2/4] hermes-skills-lib -> $LIB_DIR (публичный)"
clone_or_pull "hermes-skills-lib" "$LIB_DIR" "no"

echo "[3/4] hermes-triz-core -> $TRIZ_DIR"
clone_or_pull "hermes-triz-core" "$TRIZ_DIR" "yes"

echo "[4/4] eko-core -> $EKO_DIR"
clone_or_pull "eko-core" "$EKO_DIR" "yes"

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
