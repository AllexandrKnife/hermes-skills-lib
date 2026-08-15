# RTK Rewrite Plugin — Production Example

A complete Hermes plugin that intercepts `terminal()` commands and rewrites them through **RTK (Rust Token Killer)** `rtk rewrite` to compress output and save 60-90% on API tokens.

## Source Files

### ~/.hermes/plugins/rtk-rewrite/plugin.yaml

```yaml
name: rtk-rewrite
version: "0.1.0"
description: Rewrite Hermes terminal commands through RTK before execution.
author: RTK Contributors
hooks:
  - pre_tool_call
provides_hooks:
  - pre_tool_call
```

### ~/.hermes/plugins/rtk-rewrite/__init__.py

```python
"""Hermes plugin adapter for RTK command rewriting.

All rewrite logic lives in RTK's Rust ``rtk rewrite`` command; this module
only bridges Hermes ``pre_tool_call`` payloads to that command and fails open.
"""

import shutil
import subprocess
import sys

ACCEPTED_REWRITE_RETURN_CODES = {0, 3}
EXPECTED_PASSTHROUGH_RETURN_CODES = {1, 2}
_rtk_available = None
_rtk_missing_warned = False


def register(ctx):
    """Register the Hermes pre-tool callback."""
    if not _check_rtk():
        return
    ctx.register_hook("pre_tool_call", _pre_tool_call)


def _check_rtk():
    """Return whether the rtk binary is in PATH, warning once when missing."""
    global _rtk_available, _rtk_missing_warned
    if _rtk_available is None:
        _rtk_available = shutil.which("rtk") is not None
    if not _rtk_available and not _rtk_missing_warned:
        _warn("rtk binary not found in PATH; Hermes hook not registered")
        _rtk_missing_warned = True
    return _rtk_available


def _pre_tool_call(tool_name=None, args=None, **_kwargs):
    """Rewrite mutable Hermes terminal command args when RTK provides a change."""
    try:
        if tool_name != "terminal" or not isinstance(args, dict):
            return

        command = args.get("command")
        if not isinstance(command, str) or not command.strip():
            return

        try:
            result = subprocess.run(
                ["rtk", "rewrite", command],
                shell=False,
                timeout=2,
                capture_output=True,
                text=True,
            )
        except subprocess.TimeoutExpired:
            _warn("rtk rewrite timed out")
            return

        if result.returncode not in ACCEPTED_REWRITE_RETURN_CODES:
            if result.returncode not in EXPECTED_PASSTHROUGH_RETURN_CODES:
                details = f"rtk rewrite failed with exit {result.returncode}"
                stderr = result.stderr.strip()
                if stderr:
                    details = f"{details}: {stderr}"
                _warn(details)
            return

        rewritten = result.stdout.strip()
        if rewritten and rewritten != command:
            args["command"] = rewritten

    except Exception as e:
        _warn(str(e))
        return


def _warn(message):
    print(f"rtk: hermes plugin warning: {message}", file=sys.stderr)
```

## How It Works

1. **Startup check** — `register()` calls `_check_rtk()` using `shutil.which("rtk")`. If RTK is missing, warns once and skips registration.
2. **Per-call gate** — `_pre_tool_call` only fires for `tool_name == "terminal"`. Other tools (read_file, write_file, etc.) pass through untouched.
3. **Rewrite** — pipes the raw command string to `rtk rewrite` with a 2-second timeout.
4. **Exit code handling**:
   - `0` or `3` → rewrite available, apply it
   - `1` or `2` → no rewrite (passthrough), skip silently
   - anything else → warn on stderr
5. **Apply** — replaces `args["command"]` only if the rewritten output differs from the original.

## Registration

In `~/.hermes/config.yaml`:

```yaml
plugins:
  - rtk-rewrite
```

Restart Hermes (or CLI session) for the plugin to load.

## Verified Results

After restart, the plugin transparently intercepted all terminal() calls:

| # | Original command | Rewritten as | Input tokens | Output tokens | Saved | Efficiency |
|---|---|---|---|---|---|---|
| 1 | `ls ~/.hermes/` | `rtk ls -la .` | 717 | 239 | 478 | 66.7% |
| 2 | `ls ~/.hermes/plugins/rtk-rewrite/` | `rtk ls -la …` | 490 | 123 | 367 | 74.9% |
| 3 | `df -h /` | `rtk:toml df -h /` | — | — | 1 | 4.3% |

**Total: 6 commands, 907 tokens saved, ~69% average reduction.**

## Monitoring

Run `rtk gain` to see a dashboard of all rewritten commands and token savings:

```
RTK Token Savings (Global Scope)
════════════════════════════════════════════════════════════

Total commands:    6
Input tokens:      1.3K
Output tokens:     405
Tokens saved:      907 (69.1%)
Total exec time:   337ms (avg 56ms)
```

## Notes

- The `[warn] No hook installed — run 'rtk init -g'` message from `rtk gain` refers to a shell-level hook (bash/zsh PROMPT_COMMAND). It is IRRELEVANT when using the Hermes plugin — the plugin handles interception at the agent framework level before the command reaches the shell.
- RTK is installed at `~/.local/bin/rtk` via `cargo install rtk`. The Hermes plugin checks PATH via `shutil.which()`, so `~/.local/bin` must be in the user's PATH.
