# ECC → Hermes Import Walkthrough

Concrete example from July 2026: importing 21 skills from Everything Claude Code (ECC) into Hermes for an OSINT researcher on WSL.

## Situation

- User: OSINT researcher (Python/bash), Russian-language conversations
- Environment: Hermes Agent on WSL (Windows Subsystem for Linux)
- Target repo: github.com/affaan-m/everything-claude-code (ECC) — 278 skills, 50 agents, Claude Code/Cursor/Codex/OpenCode ecosystem

## Decision Process

### Q: Full install vs selective import?

ECC offers `install.sh --profile full` but it targets Claude Code (plugins, hooks, slash-commands). For Hermes, these are irrelevant. The repo's own `HERMES-SETUP.md` confirms: import skills only.

**Verdict:** git clone → copy skills. No install.sh.

### Q: Which skills?

278 skills available. Filtered by user domain:

| User need | Skills selected |
|-----------|----------------|
| Multi-source research | deep-research, search-first, research-ops, exa-search, knowledge-ops |
| Data collection | data-scraper-agent, browser-qa, competitive-platform-analysis, market-research |
| Security OSINT | security-review, security-scan |
| Python automation | python-patterns, python-testing, verification-loop |
| Network infrastructure | network-bgp-diagnostics, cisco-ios-patterns, network-config-validation |
| Homelab/infra | homelab-network-setup, homelab-wireguard-vpn |
| DevOps | terminal-ops, docker-patterns |

**Total: 21 skills.**

### Q: Where to put them?

`~/.hermes/skills/ecc/` — a separate namespace subdirectory to distinguish from Hermes-native skills.

## Execution

```bash
git clone --depth 1 https://github.com/affaan-m/everything-claude-code.git /root/ecc-repo
mkdir -p ~/.hermes/skills/ecc/
cp -r /root/ecc-repo/skills/{deep-research,search-first,...} ~/.hermes/skills/ecc/
```

Verified: each has SKILL.md with valid YAML frontmatter. Total 21 subdirectories.

## Notable Details

- ECC skills use `metadata.origin: ECC` in frontmatter — Hermes ignores unknown metadata fields, no conflict
- Some skills (deep-research, exa-search) require MCP servers (firecrawl, exa) that may not be configured. User was informed.
- Memory was nearly full (2,002/2,200 chars) — had to consolidate before saving the ECC entry
- The `hermes-imports` skill in ECC is for the OPPOSITE direction (Hermes → ECC), not ECC → Hermes

## Outcome

21 skills imported, accessible via `/skill ecc/skill-name` in Hermes sessions.
