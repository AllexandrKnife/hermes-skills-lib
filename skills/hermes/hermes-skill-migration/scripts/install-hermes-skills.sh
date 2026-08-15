#!/usr/bin/env bash
# Идемпотентная установка скиллов Hermes + жёсткая автозагрузка (HERMES_TUI_SKILLS).
# Проверен в песочнице 08.2026 (4 сценария: свежий / повторный / частичный / чужой скилл).
# Запуск на ЦЕЛЕВОЙ машине:  bash install.sh
# Для своих скиллов: дополнить SKILLS (имена) и SKILL_PATHS (пути относительно skills/).
set -euo pipefail

# --- Настройка: список скиллов и их пути (категории сохранять как в оригинале) ---
SKILLS="document-critic ask-first flash-pro-boost"
declare -A SKILL_PATHS=(
  ["ask-first"]="ask-first"
  ["document-critic"]="productivity/document-critic"
  ["flash-pro-boost"]="software-development/flash-pro-boost"
)
PRELOAD="$(printf '%s' "$SKILLS" | tr ' ' ',')"

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SKILLS_DIR="$HERMES_HOME/skills"
ENV_FILE="$HERMES_HOME/.env"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)/skills"

echo "==> Hermes home: $HERMES_HOME"

# 1. Проверка, что Hermes установлен
if ! command -v hermes >/dev/null 2>&1; then
  echo "!! 'hermes' не найден в PATH. Установите Hermes сначала:"
  echo "   curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"
  exit 1
fi

# 2. Копирование скиллов (сохраняя категории)
mkdir -p "$SKILLS_DIR"
for s in $SKILLS; do
  rel="${SKILL_PATHS[$s]}"
  mkdir -p "$SKILLS_DIR/$(dirname "$rel")"
  cp -r "$SRC_DIR/$rel" "$SKILLS_DIR/$(dirname "$rel")/"
done
echo "==> Скиллы скопированы в $SKILLS_DIR"

# 3. Прописываем автозагрузку в .env (без дублей, не трогая остальное)
if [ ! -f "$ENV_FILE" ]; then
  touch "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "==> Создан $ENV_FILE (chmod 600)"
fi

if grep -q '^HERMES_TUI_SKILLS=' "$ENV_FILE" 2>/dev/null; then
  # строка уже есть — проверяем, содержит ли все скиллы.
  # ВАЖНО: cut -d= -f2- — без этого case/grep не матчит ПЕРВЫЙ элемент
  # (перед ним '=', а не ','), и он дублируется при каждом запуске (баг 08.2026).
  CURRENT_VAL="$(grep '^HERMES_TUI_SKILLS=' "$ENV_FILE" | tail -1 | cut -d= -f2-)"
  MISSING=""
  for s in $SKILLS; do
    if ! printf '%s' ",$CURRENT_VAL," | grep -q ",$s,"; then
      MISSING="$MISSING,$s"
    fi
  done
  if [ -n "$MISSING" ]; then
    NEW_VALUE="${CURRENT_VAL}${MISSING}"
    sed -i "s|^HERMES_TUI_SKILLS=.*|HERMES_TUI_SKILLS=${NEW_VALUE#,}|" "$ENV_FILE"
    echo "==> HERMES_TUI_SKILLS дополнена: ${NEW_VALUE#,}"
  else
    echo "==> HERMES_TUI_SKILLS уже содержит все скиллы, без изменений"
  fi
else
  printf '\n%s\n' "HERMES_TUI_SKILLS=$PRELOAD" >> "$ENV_FILE"
  echo "==> Добавлено в $ENV_FILE: HERMES_TUI_SKILLS=$PRELOAD"
fi

# 4. Верификация
echo
echo "==> ПРОВЕРКА"
for s in $SKILLS; do
  rel="${SKILL_PATHS[$s]}"
  ls -la "$SKILLS_DIR/$rel/SKILL.md"
done
echo
echo "Автозагрузка в .env:"
grep '^HERMES_TUI_SKILLS=' "$ENV_FILE" || echo "!! HERMES_TUI_SKILLS не найдена"

echo
echo "==> ГОТОВО. Осталось: полностью выйти из hermes и запустить заново"
echo "    (прелоад читается один раз при старте процесса; /new env не перечитывает)."
echo "    В новой сессии в системном промпте появятся маркеры"
echo "    '[IMPORTANT: ... skill preloaded ...]'."
