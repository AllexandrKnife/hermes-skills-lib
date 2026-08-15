---
name: hermes-external-toolkit-integration
description: "Use when Evaluate, import, and adapt external agent"
critic_status: done
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, wsl]
metadata:
  hermes:
    tags: [hermes, skills, integration, ECC, external-toolkit, import]
    related_skills: [hermes-agent, acp-coding-agents]
---

# Hermes External Toolkit Integration

Import skills, agents, and workflows from external AI agent ecosystems (ECC, Anthropic skills, Claude Code config packs, Codex packs, OpenCode plugins) into Hermes as native skills.

## When to Use

- User asks to install or evaluate an external agent enhancement system (ECC, etc.)
- User found a useful skill pack from another ecosystem (Claude Code, Cursor, Codex)
- User wants to bring in domain-specific agents from a third-party repo
- You need to determine whether an external repo's components are Hermes-compatible

## Assessment Framework

### Step 1: Identify the target repo

Common external toolkits:

| Toolkit | Repo | Components | Hermes-compatible? |
|---------|------|------------|-------------------|
| **ECC** (Everything Claude Code) | github.com/affaan-m/everything-claude-code (alias-ссылка affaan-m/ECC; npm `ecc-universal`; plugin `ecc@ecc`) | skills/, agents/, hooks/, rules/, commands/ | **skills: yes** (SKILL.md with YAML frontmatter); **agents/commands/hooks/rules: no** (Claude Code/Cursor/Codex-specific) |
| **Anthropic Skills** | github.com/anthropics/skills | skills/ | **yes** (same SKILL.md format) |
| **Agent Skills standard repos** | github.com/agentskills/agentskills; any repo with SKILL.md at root or skills/ (e.g. book-to-skill) | SKILL.md (+ engine scripts/, tools/, tests/) | **yes** — same open standard; generator-style repos need engine code copied + host adaptation (see Step 3.5) |
| **Claude Code configs** | github.com/ search "claude-code" | .claude/, CLAUDE.md, rules/ | **rules: partial** (need manual adaptation); **agents: partial** |
| **OpenCode plugins** | npm packages | opencode.json, hooks/ | **no** (different plugin architecture) |

### Step 2: Evaluate format compatibility

Hermes native skills use `SKILL.md` with YAML frontmatter containing:
```yaml
---
name: skill-name
description: "Short description"
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [tag1, tag2]
---
```

ECC skills use the same format (`name`, `description`, `metadata.origin: ECC`) — **directly compatible**.

Non-compatible formats to watch for:
- `.claude/rules/*.md` — no YAML frontmatter, loaded by Claude Code natively
- `.cursor/rules/*.mdc` — Cursor-specific YAML format
- `opencode.json` — JSON plugin manifest, not a skill
- `AGENTS.md` / `CLAUDE.md` — project-level context files, not skills

### Step 3: Decide import scope

**Full install scripts (`install.sh`, `install.ps1`, `npx ecc-install`) target Claude Code/Cursor/Codex — DO NOT run them for Hermes.** They dump hooks, plugins, slash commands, and environment-specific configs that have no Hermes equivalent.

Instead, import only **skills/ directory** content. The procedure:

```bash
# 1. Clone the repo
git clone --depth 1 https://github.com/org/repo.git /tmp/external-repo

# 2. Verify format compatibility
ls /tmp/external-repo/skills/*/SKILL.md 2>/dev/null | head -3
head -5 /tmp/external-repo/skills/sample-skill/SKILL.md  # check YAML frontmatter

# 3. Select target skills (see Step 4)
# 4. Import to Hermes
mkdir -p ~/.hermes/skills/ecc/
cp -r /tmp/external-repo/skills/{skill-a,skill-b,skill-c} ~/.hermes/skills/ecc/

# 5. Verify
ls ~/.hermes/skills/ecc/*/SKILL.md | wc -l
```

### Step 3.5: Adapt generator-style skills (SKILL.md as a procedural spec)

Some Agent Skills ecosystem repos (e.g. book-to-skill) ship a SKILL.md that is a multi-step conversion WORKFLOW, not a static knowledge file. The body references engine code (scripts/extract.py, tools/, a Python package) by relative path. For these:

1. **Copy the engine, not just SKILL.md** — clone the repo and copy scripts/, tools/, and any packages the SKILL.md invokes into the skill directory. A SKILL.md without its scripts is a broken skill.
2. **Adapt the skill body for Hermes** (it often mentions only `name` + `description` in frontmatter — add version/author/license):

| Claude Code / Copilot / Amp | Hermes |
|---|---|
| `~/.claude/skills/<slug>/` | `~/.hermes/skills/<category>/<slug>/` (the only root Hermes discovers; default category `productivity`) |
| Bash / shell | terminal |
| Read | read_file |
| Write | write_file |
| Glob / Grep | search_files |
| `/skills reload`, `/skill-name args` | `/reload-skills`; load by name via skill_view |
| `allowed-tools` frontmatter | omit — Hermes ignores it |

3. **Strip host-specific prose** — remove slash-command docs, Copilot CLI/Amp/Claude Code mentions, and host-specific reload instructions; replace with Hermes equivalents. Keep the procedural steps intact.
4. **Verify after install**: run the repo's own test suite (pytest), run its `--check`/`--help` smoke entrypoint, then an end-to-end fixture run (small sample file through the pipeline, assert structure detection worked).

### Step 4: Select skills by user domain

Map the user's domain to relevant skill categories. For an **OSINT researcher**:

| Category | Relevant skills |
|----------|----------------|
| **Research** | deep-research, search-first, research-ops, knowledge-ops |
| **Data collection** | data-scraper-agent, browser-qa, competitive-platform-analysis, market-research |
| **Security** | security-review, security-scan |
| **Python** | python-patterns, python-testing, verification-loop |
| **Network** | network-bgp-diagnostics, cisco-ios-patterns, network-config-validation, homelab-* |
| **Infrastructure** | terminal-ops, docker-patterns |

Selection criteria:
- Prefer skills with clear `When to Use` section
- Skip skills that require Claude Code-specific hooks or plugins
- Skip skills that depend on unconfigured MCP servers (note this to user)
- Prefer skills that match the user's primary language (Python, TypeScript, Go)

### Step 5: Handle MCP Dependencies

Many external skills reference MCP servers (firecrawl, exa, GitHub, etc.). On first use, the skill will indicate what's missing.

If the user wants to configure MCPs:
```bash
hermes mcp add NAME --command "npx @modelcontextprotocol/server-..."
hermes mcp add NAME --url "https://..."
```

### Step 6: Verify

After import, check skills are discovered by Hermes:
```bash
# Load a skill in session
/skill ecc/skill-name

# Verify SKILL.md is valid
head -20 ~/.hermes/skills/ecc/skill-name/SKILL.md
```

## Pitfalls

- **Don't run `install.sh`** — ECC and similar repos target Claude Code. The install script dumps hooks, plugins, slash commands, and Claude-specific configs irrelevant to Hermes.
- **Default branch may be `master`, not `main`** — raw.githubusercontent.com/<repo>/main/<file> 404s on such repos. Query `https://api.github.com/repos/<owner>/<repo>` for `default_branch` first (or just `git clone` and read locally).
- **Host Python without pip module** — on some Linux hosts `python3 -m pip` fails ("No module named pip"); install skill deps with `uv pip install --system <pkgs>` (uv is usually present).
- **Don't layer installation methods** — If the user also uses Claude Code and installed ECC as a plugin there, importing the same skills into Hermes is fine (they're independent systems), but warn about potential confusion.
- **MCP dependency mismatch** — A skill may reference firecrawl MCPs that aren't configured in Hermes. Note this when importing.
- **Don't import the entire skills/ directory** — Many skills are Claude Code-specific (hooks, slash commands, orchestrators). Selectively pick domain-relevant ones.
- **Duplicate skill names** — If a skill from an external repo has the same name as an existing Hermes skill, the first one found in the search path wins. Rename or place in a subdirectory.
- **SKILL.md encoding** — Rarely, external repos use non-UTF-8 encoding. Check with `file SKILL.md` if imports fail silently.

## References

- `references/ecc-import-example.md` — concrete walkthrough of importing 21 ECC skills for OSINT research, with selection rationale and MCP notes
- `references/ecc-2026-evaluation.md` — ECC project evaluation (v2.0.0-rc.1, апр 2026): три идентификатора репо, вердикт совместимости с Hermes, отбор скиллов для домена «аудит/аналитика» (AgentShield npx CLI, content-hash-cache, regex-vs-llm, cost-aware-llm), список пропуска, паттерны для концептуального переноса, чтение README через curl
- `references/agent-skills-port-example.md` — concrete walkthrough of porting the Agent Skills standard repo book-to-skill (Claude Code) into Hermes: engine copy, SKILL.md adaptation, dependency install, verification
