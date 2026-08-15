# Skill Sync 2026-08 — Frankfurt VPS → WSL (exact session commands)

Session 02.08.2026: audit + transfer of 6 agent-created skills from
45.134.15.185 (Frankfurt) to local WSL. All commands verified working.

## Context

- VPS 45.134.15.185, Ubuntu 22.04, SSH root via sshpass (creds in memory)
- Local: WSL, skills at /root/.hermes/skills
- VPS had ~115 skills; 35 non-bundled, 10 agent-created

## 1. Audit (run on VPS)

```bash
# list all skills + categories
for f in $(find /root/.hermes/skills/ -maxdepth 4 -name "SKILL.md" | sort); do
  name=$(grep -m1 "^name:" "$f" | sed "s/name: *//")
  desc=$(grep -m1 "^description:" "$f" | sed "s/description: *//" | cut -c1-80)
  echo "$name :: $desc"
done

# agent-created with metadata (equivalent to scripts/skill-diff.py)
python3 - <<'PYEOF'
import os, json
usage = json.load(open("/root/.hermes/skills/.usage.json"))
rows = [(n, m) for n, m in usage.items() if m.get("created_by") == "agent"]
rows.sort(key=lambda r: r[1].get("created_at") or "")
for name, meta in rows:
    print("%-40s created=%s used=%s patched=%s %s" % (
        name, (meta.get("created_at") or "")[:19],
        (meta.get("last_used_at") or "")[:19],
        (meta.get("last_patched_at") or "")[:19],
        "ARCHIVED" if meta.get("archived_at") else ""))
PYEOF
```

Key facts learned:
- `.bundled_manifest` = `name:md5` lines, plain text, NOT JSON
- `.usage.json` = dict name → {created_at, created_by, last_used_at,
  last_patched_at, archived_at}
- `created_by=agent` = auto-created by the agent, not hub/bundled
- A "skill" entry in usage.json may be a reference dir inside another skill
  (e.g. browser-use lived under software-development/browser-automation/references/)
  — resolve real path with `find /root/.hermes/skills -maxdepth 4 -type d -name "$s"`

## 2. Transfer — scp FAILED, tar-over-ssh worked

```bash
# scp multi-source failed: exit 5, only first dir landed
sshpass -p '<pass>' scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r \
  root@45.134.15.185:/root/.hermes/skills/research/e-commerce-pricing \
  ... /root/.hermes/skills/    # exit 5, partial copy!

# workaround: tar over ssh pipe
sshpass -p '<pass>' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@45.134.15.185 \
  'cd /root/.hermes/skills && tar czf - research/e-commerce-pricing \
   red-teaming/domain-investigation software-development/browser-automation \
   research/web-article-extraction research/open-source-project-evaluation \
   red-teaming/ioc-enrichment /root/scripts/enrich.py 2>/dev/null' \
  > /tmp/skills.tar.gz
tar xzf /tmp/skills.tar.gz -C /    # ← relative entries went to /research, /red-teaming...
```

## 3. The -C / pitfall (fix)

Archive mixed relative paths (research/...) with an absolute path
(/root/scripts/enrich.py → stored as root/scripts/enrich.py). Extraction with
`-C /` scattered dirs into /research, /red-teaming, /software-development at
filesystem root. Fix:

```bash
rm -rf /root/.hermes/skills/e-commerce-pricing   # partial scp leftover, no category
mv /research/e-commerce-pricing /root/.hermes/skills/research/
mv /research/web-article-extraction /root/.hermes/skills/research/
mv /research/open-source-project-evaluation /root/.hermes/skills/research/
mv /red-teaming/domain-investigation /root/.hermes/skills/red-teaming/
mv /red-teaming/ioc-enrichment /root/.hermes/skills/red-teaming/
mv /software-development/browser-automation /root/.hermes/skills/software-development/
rmdir /research /red-teaming /software-development
```

Cleaner: extract to a staging dir first, or `cd /root/.hermes/skills && tar xzf -`,
or archive everything relative to one root.

## 4. Dependency check (ioc-enrichment → enrich.py)

ioc-enrichment/SKILL.md referenced /root/scripts/enrich.py — copied it along:
`scp root@45.134.15.185:/root/scripts/enrich.py /root/scripts/` (single-file scp
worked even when multi-source scp failed — another reason to verify after copy).
Verified: `python3 /root/scripts/enrich.py --help` → usage printed.

## 5. Final verification

```bash
for s in research/e-commerce-pricing red-teaming/domain-investigation \
         software-development/browser-automation research/web-article-extraction \
         research/open-source-project-evaluation red-teaming/ioc-enrichment; do
  ls -d /root/.hermes/skills/$s && find /root/.hermes/skills/$s -name SKILL.md | head -1
done
```

## Selected skills (from 10 agent-created, ranked by fit for СББП work)

Taken (6): e-commerce-pricing (рыночные цены для проверки смет),
domain-investigation (рекон контрагентов), browser-automation (headless сбор
данных), web-article-extraction (Jina Reader), open-source-project-evaluation,
ioc-enrichment (+ enrich.py).

Left on VPS (4): security-audit (код-ревью — не профиль), adguard-home (уже
развёрнут), kimi-webbridge (дубль browser-use), system-status (инфраструктура VPS).
