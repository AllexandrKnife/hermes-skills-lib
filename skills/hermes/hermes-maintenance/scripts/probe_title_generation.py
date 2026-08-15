#!/usr/bin/env python3
"""Live probe: Hermes auxiliary title generation through real code + config.

Verifies the FULL path (provider resolution from config.yaml -> LLM call ->
response) WITHOUT starting a complete Hermes session. Use after changing
auxiliary.<task>.provider in config.yaml, or when title generation fails
with HTTP 400/403/422.

Usage:
  /usr/local/lib/hermes-agent/venv/bin/python probe_title_generation.py \
      "тестовое сообщение пользователя"

Exit: prints TITLE_OK:<title> on success (exit 0), TITLE_FAIL:<reason> on
failure (exit 1).
"""
import sys, os

sys.path.insert(0, "/usr/local/lib/hermes-agent")
os.chdir("/usr/local/lib/hermes-agent")

from agent.title_generator import generate_title  # noqa: E402

msg = sys.argv[1] if len(sys.argv) > 1 else "тестовый запрос"
try:
    title = generate_title(msg, timeout=60)
    print("TITLE_OK:", repr(title))
except Exception as e:
    print("TITLE_FAIL:", type(e).__name__, str(e)[:500])
    sys.exit(1)
