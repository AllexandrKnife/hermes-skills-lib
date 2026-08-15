---
name: hermes-plugin-development
description: "Create Hermes Agent plugins with hooks (pre_tool_call, etc.) to intercept and modify tool calls. Covers plugin structure, hook registration, fail-open pattern, and verification."
version: 1.0.0
author: Hermes Agent
triggers:
  - "create a plugin"
  - "написать плагин"
  - "hermes plugin"
  - "pre_tool_call"
  - "rewrite terminal commands"
  - "intercept tool calls"
license: MIT
platforms: [linux, macos, wsl]
metadata:
  hermes:
    tags: [hermes, plugin, hooks, extension]
    related_skills: [hermes-agent, tool-evaluation]
---

# Hermes Plugin Development

Create Hermes Agent plugins that hook into tool calls. Plugins live in `~/.hermes/plugins/<name>/` and are registered in `~/.hermes/config.yaml` under the `plugins` key.

## Plugin Structure

Each plugin is a directory with two files:

```
~/.hermes/plugins/<name>/
├── plugin.yaml       # Metadata + hook declarations
└── __init__.py       # Hook implementations
```

### plugin.yaml

```yaml
name: my-plugin
version: "0.1.0"
description: What this plugin does.
author: Your Name
hooks:
  - pre_tool_call
provides_hooks:
  - pre_tool_call
```

The `hooks` field lists the hooks this plugin registers. `provides_hooks` is a repeat for tooling introspection — keep them in sync.

### __init__.py — The Register Function

Every plugin must expose a `register(ctx)` function. Hermes calls it at startup:

```python
def register(ctx):
    """Register hooks with the Hermes runtime."""
    ctx.register_hook("pre_tool_call", _my_hook)
```

`ctx.register_hook(hook_name, callback)` attaches your handler. Available hook names (confirmed):

| Hook | Signature | Fires |
|------|-----------|-------|
| `pre_tool_call` | `(tool_name, args, **_kwargs)` | Before every tool call |

## pre_tool_call Hook Pattern

The hook receives the tool name and its arguments as a dict. Modify `args` in-place to change what the tool receives.

### Canonical Pattern (Fail-Open)

```python
import subprocess
import sys

ACCEPTED_RETURN_CODES = {0, 3}
PASSTHROUGH_RETURN_CODES = {1, 2}

def _pre_tool_call(tool_name=None, args=None, **_kwargs):
    """Rewrite terminal command args in-place."""
    try:
        # 1. Gate: only intercept the target tool
        if tool_name != "terminal" or not isinstance(args, dict):
            return

        command = args.get("command")
        if not isinstance(command, str) or not command.strip():
            return

        # 2. Transform: call an external tool to rewrite
        try:
            result = subprocess.run(
                ["external-tool", command],
                shell=False,
                timeout=2,
                capture_output=True,
                text=True,
            )
        except subprocess.TimeoutExpired:
            _warn("external-tool timed out")
            return

        # 3. Interpret exit codes
        if result.returncode not in ACCEPTED_RETURN_CODES:
            if result.returncode not in PASSTHROUGH_RETURN_CODES:
                stderr = result.stderr.strip()
                details = f"external-tool failed ({result.returncode})"
                if stderr:
                    details += f": {stderr}"
                _warn(details)
            return

        # 4. Apply rewrite
        rewritten = result.stdout.strip()
        if rewritten and rewritten != command:
            args["command"] = rewritten

    except Exception as e:
        _warn(str(e))
        return  # Fail open — never block the tool call


def _warn(message):
    print(f"plugin: warning: {message}", file=sys.stderr)
```

### Key Rules

1. **FAIL OPEN** — any exception returns silently. The plugin should never prevent the tool call from executing.
2. **Always warn** on errors to stderr so the user sees the plugin degraded, but doesn't lose the command.
3. **Timeout aggressively** — 2s max. A slow rewrite is worse than no rewrite.
4. **Gate on tool_name** — only intercept the tool(s) you care about. Avoid touching `read_file`, `write_file`, etc. unless intended.
5. **Preserve passthrough exit codes** — define a set of codes that mean "no rewrite available" (e.g. 1 or 2) vs "I tried but broke" (unexpected code). Log the latter, skip silently on the former.

## Registration: config.yaml

Add the plugin name to the `plugins` list:

```yaml
plugins:
  - my-plugin
```

The plugin directory name must match the name in this list.

## Verification

After adding a plugin and restarting Hermes, verify it works:

1. **Check logs for warnings** — look for your `_warn` messages
2. **Run a test command** that the plugin should intercept
3. **Use a dashboard** (e.g. `rtk gain`) if the rewrite tool provides token-saving metrics
4. **Check edge cases:**
   - Empty command → should not crash
   - Non-terminal tool → should be ignored
   - Network timeout → should return gracefully

## Example: RTK (Rust Token Killer) Plugin

See the reference file at `references/rtk-rewrite-plugin.md` for a complete production example — a Hermes plugin that rewrites terminal commands through `rtk rewrite` to compress output and save 60-90% on API tokens.

## Pitfalls

1. **Don't modify non-terminal args.** The `args` dict is shared — only change keys you own. For terminal, only `command` is safe to rewrite.
2. **Don't block the tool call.** Always return `None` (implicitly). Never raise. Always catch all exceptions.
3. **Don't run expensive transforms.** The hook fires on every tool call. Keep subprocess calls under 2s timeout.
4. **Don't mutate without a diff.** Only set `args["command"]` when the rewritten output is actually different from the original. Otherwise you waste tokens on a pointless round-trip.
5. **Respect existing conventions.** The plugin's Hermes agent runs as the user, in their shell. Don't assume `PATH` or environment — use `shutil.which()` for binary availability checks.
6. **Register with a check first.** Call `register()` only if prerequisites are met (binary in PATH, config valid). Warn once, then skip registration silently on subsequent runs.
