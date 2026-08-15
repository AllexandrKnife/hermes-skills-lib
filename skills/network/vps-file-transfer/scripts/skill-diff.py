#!/usr/bin/env python3
"""Audit a Hermes skills root: list non-bundled and agent-patched skills.

Usage:
    python3 skill-diff.py /root/.hermes/skills [--all]

Reads .bundled_manifest (name:md5 lines) and .usage.json (per-skill metadata)
in the skills root. Prints:
  (a) skills NOT in the bundled manifest (custom / hub / agent-created)
  (b) bundled skills patched after install (created_by=agent or last_patched_at)

Use before copying skills between machines to decide what is worth syncing.
"""
import os
import re
import sys
import json
import glob

skills_root = sys.argv[1] if len(sys.argv) > 1 else "/root/.hermes/skills"
show_all = "--all" in sys.argv

bundled = set()
manifest_path = os.path.join(skills_root, ".bundled_manifest")
if os.path.exists(manifest_path):
    for line in open(manifest_path):
        line = line.strip()
        if ":" in line:
            bundled.add(line.split(":")[0])

found = {}
for f in glob.glob(os.path.join(skills_root, "**", "SKILL.md"), recursive=True):
    if any(x in f for x in (".archive", ".curator_backups", ".hub")):
        continue
    text = open(f, encoding="utf-8", errors="replace").read(2000)
    m = re.search(r"^name:\s*(\S+)", text, re.M)
    name = m.group(1) if m else os.path.basename(os.path.dirname(f))
    found[name] = f

usage = {}
usage_path = os.path.join(skills_root, ".usage.json")
if os.path.exists(usage_path):
    usage = json.load(open(usage_path))

print("=== NOT IN BUNDLED MANIFEST (custom) ===")
for name in sorted(found):
    if name not in bundled:
        meta = usage.get(name, {})
        created = (meta.get("created_at") or "")[:10]
        by = meta.get("created_by") or "-"
        print("%-45s created=%s by=%s  %s" % (
            name, created, by, found[name].replace(skills_root, "")))

print()
print("=== IN BUNDLE BUT AGENT-PATCHED ===")
for name in sorted(found):
    if name in bundled:
        meta = usage.get(name, {})
        if meta.get("created_by") == "agent" or meta.get("last_patched_at"):
            print("%-45s patched=%s  %s" % (
                name, str(meta.get("last_patched_at"))[:10],
                found[name].replace(skills_root, "")))

if show_all:
    print()
    print("=== ALL SKILLS WITH USAGE METADATA ===")
    for name in sorted(usage):
        meta = usage.get(name, {})
        print("%-45s created=%s used=%s archived=%s" % (
            name, (meta.get("created_at") or "")[:10],
            (meta.get("last_used_at") or "")[:10],
            "YES" if meta.get("archived_at") else ""))
