---
name: vps-file-transfer
description: "Use when copying files between WSL and VPS over SSH."
critic_status: done
version: 1.0.0
tags: [vps, ssh, scp, tar, file-transfer, wsl, hermes-skills, sync]
---

# VPS ↔ WSL File Transfer

## Trigger

- Copy files or directories from a VPS to WSL (or WSL → VPS) over SSH
- `scp` fails with exit code 5 (SFTP subsystem disabled/misconfigured on server)
- Batch-copy multiple directories / skill trees between machines
- Synchronizing Hermes skills from a remote install to local

## SSH access pattern (password auth)

```bash
sshpass -p '<pass>' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  -o UserKnownHostsFile=/dev/null root@<VPS-IP> 'command'
```

- `UserKnownHostsFile=/dev/null` — don't pollute local known_hosts with ad-hoc IPs
- `ConnectTimeout=10` — fail fast, don't hang
- Password/creds live in memory, not in skills; `sshpass` is the standard helper

## Pitfall: scp exit code 5 (SFTP subsystem failure)

**Symptom**: `scp -r src1 src2 ... root@IP:/dest` returns exit 5 with only a
`Warning: Permanently added ...` line, while `ssh` to the same host works fine.
Server-side SFTP subsystem is broken/disabled (common on minimal VPS images).

**Critical**: multi-source scp can PARTIALLY succeed — first source copied,
later ones failed, exit 5 overall. **Never trust the exit code; always verify
what actually landed** (`ls -d` / `find` the expected paths).

**Workaround — tar over ssh pipe** (ssh still works; only SFTP is broken):

```bash
# remote → local
sshpass -p '<pass>' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@<VPS-IP> 'cd /root/.hermes/skills && tar czf - dirA dirB /abs/path/file 2>/dev/null' \
  > /tmp/out.tar.gz
tar xzf /tmp/out.tar.gz -C /target/dir

# local → remote
tar czf - dirA | sshpass -p '<pass>' ssh -o StrictHostKeyChecking=no root@<VPS-IP> 'cat > /tmp/out.tar.gz && cd /target && tar xzf /tmp/out.tar.gz'
```

## Pitfall: tar archive with MIXED absolute and relative paths

`cd /root/.hermes/skills && tar czf - relative/dir /root/scripts/file` produces an
archive whose entries have different styles:

- **Relative entries** (`research/e-commerce-pricing`) extract relative to the `-C` dir.
  With `-C /` they land in `/research`, `/red-teaming`, ... (happened 08.2026 — had to `mv` into `~/.hermes/skills/<cat>/`).
- **Absolute entries** (`root/scripts/enrich.py` — tar strips the leading `/`) extract
  relative to `-C` too, so `-C /` puts them at `/root/scripts/...` — correct only by luck.

**Fix**: extract into a staging dir then `mv`, or archive with all paths relative to a
single root and extract with the matching `-C`, or use `--strip-components=N`.
After extraction always `ls -d` each expected destination.

## Copying Hermes skills between machines (audit first)

Skills live in `~/.hermes/skills/<category>/<skill-name>/`. Before copying, find out
what's custom vs bundled — the audit script `scripts/skill-diff.py` (run ON the source
machine, typically the VPS):

```bash
# copy script to remote and run
python3 skill-diff.py /root/.hermes/skills
```

It reads two hidden files in the skills root:
- `.bundled_manifest` — `name:md5` lines = skills shipped with Hermes
- `.usage.json` — per-skill metadata: `created_by` (agent = auto-created),
  `created_at`, `last_used_at`, `last_patched_at`, `archived_at`

Output: (a) skills NOT in the manifest (custom/installed), (b) bundled skills
patched by agent (`created_by=agent` or `last_patched_at` set). Use `last_used_at`
to spot abandoned vs actively-used skills.

**Dependency check**: a skill may reference scripts outside its own dir
(e.g. `ioc-enrichment` → `/root/scripts/enrich.py`). `grep -n` the SKILL.md for
`/root/`, `/usr/` paths and copy those dependencies too — otherwise the skill is
broken locally. Verify with `python3 <script> --help` after transfer.

## Verification checklist after transfer

1. `ls -d` every expected `<category>/<skill-name>` dir
2. `find <dir> -name SKILL.md` — frontmatter present
3. `find <dir> -name references -type d` — support files kept
4. Run any external script the skill references (`--help`) — path compatibility
5. Clean up staging dirs (`/research`, `/red-teaming` at `/` — leftover from the -C / pitfall)

## References

- `references/skill-sync-2026-08.md` — session transcript: full audit + transfer of 6 skills from Frankfurt VPS, exact commands.

## Related skills

- secure-copy-windows-wsl / win-pull — Windows host → WSL copies (different source, same class family)
- skill-audit — SKILL.md content integrity checks
