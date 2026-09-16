#!/usr/bin/env bash
# install-skills.sh — установка рабочей системы Hermes из ЕДИНОГО зеркала.
#
# Источник: приватный репозиторий AllexandrKnife/hermes-system-mirror.
# Он содержит ВСЮ систему: SOUL.md, config.yaml, memories, mem_lib.md, скиллы,
# библиотеки (skills-lib/triz-core), скрипты, планы, plugins, cron/jobs.json.
#
# Использование:
#   GITHUB_TOKEN=<token> bash install-skills.sh [--base-dir DIR] [--dry-run] [--with-data]
#   или (после того как токен в ~/.git-credentials):
#   bash install-skills.sh
#
#   --base-dir DIR — префикс для путей установки (песочница/тест).
#   --dry-run      — показать, что будет установлено, ничего не записывая.
#   --with-data    — дополнительно развернуть данные/ и проекты/ (рабочие каталоги
#                    и файлы) в <base>/. Без флага ставится только система;
#                    файлы, совпадающие по имени, перезаписываются.
#
# Режимы (автоопределение, переопределяется через HERMES_INSTALL_MODE):
#   root:  система -> /root/...            (полная раскладка по рабочим путям)
#   user:  система -> $HOME/...            (+ sed-замена /root/ -> $HOME/ в скиллах)
#
# ВАЖНО: зеркало содержит ЖИВЫЕ СЕКРЕТЫ (ключи API в config.yaml и в скиллах).
# Репозиторий обязан оставаться приватным. Скрипт проверяет это перед установкой.
#
# Раскладка зеркала -> рабочие пути:
#   hermes/SOUL.md            -> <hermes_home>/SOUL.md
#   hermes/config.yaml        -> <hermes_home>/config.yaml
#   hermes/mem_lib.md         -> <hermes_home>/mem_lib.md
#   hermes/memories/*         -> <hermes_home>/memories/*
#   hermes/skills/*           -> <hermes_home>/skills/*
#   hermes/scripts/*          -> <hermes_home>/scripts/*
#   hermes/plugins/*          -> <hermes_home>/plugins/*
#   hermes/plans/*            -> <hermes_home>/plans/*
#   hermes/cron/jobs.json     -> <hermes_home>/cron/jobs.json
#   hermes-skills-lib/*       -> <lib_root>/hermes-skills-lib/*
#   hermes-triz-core/*        -> <lib_root>/hermes-triz-core/*
#   plans/*                   -> <lib_root>/plans/*
#   scripts/*                 -> <lib_root>/scripts/*
#   служебные-инфраструктура/ -> <lib_root>/служебные-инфраструктура/
#   skills-migration/         -> <lib_root>/skills-migration/
#   memory/*                  -> <base>/memory/*
#   данные/*                  -> <base>/*      (только с --with-data)
#   проекты/*                 -> <base>/*      (только с --with-data)

set -uo pipefail

SCRIPT_VERSION="2026-09-16c+mirror-data"
MIRROR_REPO="hermes-system-mirror"

# --- Аргументы ------------------------------------------------------------------
BASE_DIR_ARG=""
DRY_RUN="no"
WITH_DATA="no"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir) BASE_DIR_ARG="${2:-}"; shift 2 ;;
    --dry-run)  DRY_RUN="yes"; shift ;;
    --with-data) WITH_DATA="yes"; shift ;;
    -h|--help)
      sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 1 ;;
  esac
done

# --- Пользователь GitHub --------------------------------------------------------
GITHUB_USER="${GITHUB_USER:-Allexandr_Knife}"
# В URL GitHub логин может отличаться от отображаемого имени
GITHUB_LOGIN="${GITHUB_LOGIN:-AllexandrKnife}"

# --- Режим и пути ---------------------------------------------------------------
MODE="${HERMES_INSTALL_MODE:-}"
if [[ -z "$MODE" ]]; then
  if [[ "$(id -u)" == "0" ]]; then MODE="root"; else MODE="user"; fi
fi

if [[ "$MODE" == "root" ]]; then
  BASE="${BASE_DIR_ARG:-/root}"
else
  BASE="${BASE_DIR_ARG:-$HOME}"
fi

HERMES_HOME="${BASE}/.hermes"
SKILLS_DIR="${HERMES_HOME}/skills"
MEMORIES_DIR="${HERMES_HOME}/memories"
HSCRIPTS_DIR="${HERMES_HOME}/scripts"
PLUGINS_DIR="${HERMES_HOME}/plugins"
HPLANS_DIR="${HERMES_HOME}/plans"
CRON_DIR="${HERMES_HOME}/cron"
LIB_ROOT="${BASE}"
LIB_DIR="${LIB_ROOT}/hermes-skills-lib"
TRIZ_DIR="${LIB_ROOT}/hermes-triz-core"
PLANS_DIR="${LIB_ROOT}/plans"
SCRIPTS_DIR="${LIB_ROOT}/scripts"
SERV_DIR="${LIB_ROOT}/служебные-инфраструктура"
MIGR_DIR="${LIB_ROOT}/skills-migration"
MEM_DIR="${BASE}/memory"

# --- Токен ---------------------------------------------------------------------
get_token() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    TOKEN="$GITHUB_TOKEN"
  elif [[ -f "$HOME/.git-credentials" ]]; then
    TOKEN="$(grep 'github.com' "$HOME/.git-credentials" 2>/dev/null | grep -oE '(ghp_|github_pat_)[A-Za-z0-9_]+' | head -1 || true)"
  fi
  if [[ -z "${TOKEN:-}" ]]; then
    if [[ -r /dev/tty ]]; then
      read -r -s -p "GitHub token (репо приватный): " TOKEN < /dev/tty
      echo
    fi
  fi
  if [[ -z "${TOKEN:-}" ]]; then
    echo "Ошибка: токен не получен." >&2
    echo "Запустите: GITHUB_TOKEN=<ваш-токен> bash install-skills.sh" >&2
    echo "или положите токен в ~/.git-credentials (формат https://USER:TOKEN@github.com)." >&2
    exit 1
  fi
}

# --- Проверка, что зеркало приватное (защита от публикации с секретами) ---------
check_private() {
  local vis
  vis="$(curl -fsS -H "Authorization: token ${TOKEN}" \
        "https://api.github.com/repos/${GITHUB_LOGIN}/${MIRROR_REPO}" 2>/dev/null \
        | grep -o '"private":[a-z]*' | head -1 | cut -d: -f2)"
  if [[ "$vis" == "false" ]]; then
    echo "СТОП: репозиторий ${GITHUB_LOGIN}/${MIRROR_REPO} ПУБЛИЧНЫЙ, а в нём живые секреты." >&2
    echo "Сделайте его приватным и повторите (или отзовите ключи перед публикацией)." >&2
    exit 1
  fi
  [[ "$vis" == "true" ]] && echo "  приватность зеркала: подтверждена"
}

# --- Скачивание зеркала ---------------------------------------------------------
# Клонирует зеркало в <BASE>/.hermes-mirror (или обновляет существующее).
fetch_mirror() {
  local url dir="${BASE}/.hermes-mirror"
  url="https://${GITHUB_USER}:${TOKEN}@github.com/${GITHUB_LOGIN}/${MIRROR_REPO}.git"
  if [[ -d "$dir/.git" ]]; then
    echo "  зеркало уже скачано — обновляю (git pull)"
    # Тянем с токеном в URL: на чистой машине ~/.git-credentials может отсутствовать, а pull
    # по origin без токена в приватный репо падает. Раньше ошибка глушилась (2>/dev/null) и
    # установка молча шла из СТАРОГО зеркала — теперь провал видно. Правка 16.09.2026.
    if ! git -C "$dir" pull --ff-only --quiet "$url" main 2>/dev/null \
       && ! git -C "$dir" pull --quiet "$url" main 2>/dev/null; then
      echo "  [!] обновить зеркало не удалось — ставлю из того, что скачано ранее" >&2
      echo "      проверь доступ к ${GITHUB_LOGIN}/${MIRROR_REPO} (токен/права)" >&2
    fi
  else
    echo "  клонирую зеркало..."
    git clone --depth 1 --quiet "$url" "$dir" || {
      echo "Ошибка: не удалось склонировать зеркало ${GITHUB_LOGIN}/${MIRROR_REPO} (проверь токен/доступ)." >&2
      return 1
    }
  fi
  # Токен не оставляем в .git/config (гигиена: он и так в ~/.git-credentials)
  git -C "$dir" remote set-url origin "https://github.com/${GITHUB_LOGIN}/${MIRROR_REPO}.git" 2>/dev/null || true
  echo "$dir"
}

# --- Копирование с сохранением неотслеживаемого ---------------------------------
# copy_tree <src> <dst> — копирует содержимое (включая скрытое), не удаляя чужое.
copy_tree() {
  local src="$1" dst="$2"
  if [[ "$DRY_RUN" == "yes" ]]; then echo "    [dry] $src -> $dst"; return 0; fi
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude='.git/' "$src"/ "$dst"/
  else
    (cd "$src" && tar cf - --exclude=.git .) | (cd "$dst" && tar xf -)
  fi
}

# --- Раскладка ------------------------------------------------------------------
layout() {
  local m="$1"
  echo "[1/7] ядро агента -> $HERMES_HOME"
  for f in SOUL.md config.yaml; do
    if [[ -f "$m/hermes/$f" ]]; then
      echo "    $f"
      [[ "$DRY_RUN" == "yes" ]] || { mkdir -p "$HERMES_HOME"; cp -f "$m/hermes/$f" "$HERMES_HOME/$f"; }
    fi
  done
  [[ -f "$m/hermes/mem_lib.md" ]] && { echo "    mem_lib.md"; [[ "$DRY_RUN" == "yes" ]] || cp -f "$m/hermes/mem_lib.md" "$HERMES_HOME/mem_lib.md"; }
  copy_tree "$m/hermes/memories" "$MEMORIES_DIR"

  echo "[2/7] скиллы -> $SKILLS_DIR"
  copy_tree "$m/hermes/skills" "$SKILLS_DIR"

  echo "[3/7] скрипты/плагины/планы агента -> $HERMES_HOME"
  copy_tree "$m/hermes/scripts" "$HSCRIPTS_DIR"
  copy_tree "$m/hermes/plugins" "$PLUGINS_DIR"
  copy_tree "$m/hermes/plans"   "$HPLANS_DIR"
  if [[ -f "$m/hermes/cron/jobs.json" ]]; then
    echo "    cron/jobs.json"
    [[ "$DRY_RUN" == "yes" ]] || { mkdir -p "$CRON_DIR"; cp -f "$m/hermes/cron/jobs.json" "$CRON_DIR/jobs.json"; }
  fi

  echo "[4/7] библиотеки -> $LIB_ROOT"
  copy_tree "$m/hermes-skills-lib" "$LIB_DIR"
  copy_tree "$m/hermes-triz-core"  "$TRIZ_DIR"

  echo "[5/7] рабочие планы и скрипты -> $LIB_ROOT"
  copy_tree "$m/plans"   "$PLANS_DIR"
  copy_tree "$m/scripts" "$SCRIPTS_DIR"
  copy_tree "$m/служебные-инфраструктура" "$SERV_DIR"
  copy_tree "$m/skills-migration" "$MIGR_DIR"
  copy_tree "$m/memory" "$MEM_DIR"

  echo "[6/7] данные и проекты -> $BASE"
  if [[ "$WITH_DATA" == "yes" ]]; then
    for d in "данные" "проекты"; do
      [[ -d "$m/$d" ]] || continue
      echo "    $d/ -> $BASE/ ($(find "$m/$d" -type f 2>/dev/null | wc -l || true) файлов)"
      copy_tree "$m/$d" "$BASE"
    done
  else
    echo "    пропущено (нужен флаг --with-data)"
  fi

  echo "[7/7] user-режим: правка абсолютных путей /root -> \$HOME"
  if [[ "$MODE" == "user" && "$DRY_RUN" == "no" ]]; then
    local fixed=0
    for d in "$SKILLS_DIR" "$LIB_DIR" "$TRIZ_DIR" "$PLANS_DIR" "$SCRIPTS_DIR" \
             "$SERV_DIR" "$MIGR_DIR" "$MEM_DIR" "$HERMES_HOME/scripts"; do
      [[ -d "$d" ]] || continue
      grep -rlZ '/root/' "$d" 2>/dev/null | xargs -0 -r sed -i "s#/root/#$BASE/#g" || true
    done
    # считаем именно НЕпереписанные ссылки: свои новые пути начинаются с $BASE/ и не в счёт
    fixed="$(grep -rho "/root/[A-Za-zА-Яа-яЁё0-9_./-]*" "$SKILLS_DIR" "$LIB_DIR" "$TRIZ_DIR" "$PLANS_DIR" 2>/dev/null | grep -v "^${BASE}/" | wc -l || true)"
    echo "    переписано: скиллы, библиотеки, планы, скрипты, память (осталось чужих ссылок /root/: ${fixed})"
  else
    echo "    пропущено (режим ${MODE})"
  fi
}

# --- Основная логика ------------------------------------------------------------
for _cmd in git curl; do
  command -v "$_cmd" >/dev/null 2>&1 || { echo "Ошибка: $_cmd не установлен." >&2; exit 1; }
done

echo "Установка системы Hermes из зеркала (режим: ${MODE}, база: ${BASE}, скрипт v${SCRIPT_VERSION})"
[[ "$DRY_RUN" == "yes" ]] && echo "РЕЖИМ DRY-RUN: ничего не записывается"

get_token
check_private

MIRROR_DIR="$(fetch_mirror | tail -1)"
[[ -d "$MIRROR_DIR" ]] || { echo "Ошибка: зеркало не скачано." >&2; exit 1; }

layout "$MIRROR_DIR"

echo
echo "=== Результат ==="
printf "  %-22s %s\n" "SOUL.md"    "$([[ -f $HERMES_HOME/SOUL.md ]] && echo 'есть' || echo 'НЕТ')"
printf "  %-22s %s\n" "config.yaml" "$([[ -f $HERMES_HOME/config.yaml ]] && echo 'есть' || echo 'НЕТ')"
printf "  %-22s %s\n" "скиллы"      "$(find "$SKILLS_DIR" -name SKILL.md 2>/dev/null | wc -l) шт."
printf "  %-22s %s\n" "библиотека"  "$(find "$LIB_DIR" -name 'SKILL.md' 2>/dev/null | wc -l) шт."
printf "  %-22s %s\n" "триз-ядро"   "$(find "$TRIZ_DIR" -name '*.md' 2>/dev/null | wc -l) файлов"
printf "  %-22s %s\n" "планы"       "$(find "$PLANS_DIR" -name '*.md' -o -name '*.py' 2>/dev/null | wc -l) файлов"
printf "  %-22s %s\n" "память (memory/)" "$(find "$MEM_DIR" -type f 2>/dev/null | wc -l) файлов"
# Секреты в зеркало не кладутся (приватный master-файл вне белого списка сборщика).
# Без него провайдеры в config.yaml (api_key пустые) не ответят — говорим это прямо.
if [[ -f "${HOME}/.secrets.env" ]]; then
  printf "  %-22s %s\n" "секреты" "~/.secrets.env — найден"
else
  printf "  %-22s %s\n" "секреты" "~/.secrets.env — НЕТ (перенесите вручную, иначе LLM-провайдеры не ответят)"
fi
if [[ "$WITH_DATA" == "yes" ]]; then
  printf "  %-22s %s\n" "данные+проекты" "$(( $( [[ -d "$BASE/Отчёты" ]] && echo 1 || echo 0 ) + $( [[ -d "$BASE/sbbp-case" ]] && echo 1 || echo 0 ) ))/2 ключевых каталогов на месте ($BASE)"
fi
echo
echo "Дальше:"
echo "  1) перенесите ~/.secrets.env — в зеркало секреты не кладутся (в config.yaml api_key пустые)"
echo "  2) проверьте config.yaml — провайдеры/модели/пути под машину"
echo "  3) перезапустите Hermes (новая сессия), чтобы подхватились SOUL и скиллы"
echo "  4) повторный запуск безопасен и обновит систему (git pull в ${BASE}/.hermes-mirror)"
