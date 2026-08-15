#!/usr/bin/env python3
"""Инвентаризация библиотеки скилов Hermes: отделить кастомные от стандартных,
найти созданные агентом, показать жизненный цикл (создан/использован/патчен).

Работает локально и по SSH (закинуть на VPS через heredoc, запустить python3).
Источники: ~/.hermes/skills/.bundled_manifest + .usage.json

Выход:
  1) «НЕ СТАНДАРТНЫЕ (нет в bundled_manifest)» — name / created / by / путь
  2) «ЕСТЬ В БАНДЛЕ, НО created_by=agent/patched» — модифицированные бандловые

Pitfall: в ssh heredoc с f-string использовать НЕЛЬЗЯ (backslash в выражении
f-string = SyntaxError). Скрипт специально на .format(), чтобы можно было
передавать как есть внутри 'PYEOF'.
"""
import os, json, re, glob

skills_root = os.environ.get("SKILLS_ROOT", os.path.expanduser("~/.hermes/skills"))
bundled = set()
for line in open(os.path.join(skills_root, ".bundled_manifest"), encoding="utf-8"):
    line = line.strip()
    if ":" in line:
        bundled.add(line.split(":")[0])

found = {}
for f in glob.glob(os.path.join(skills_root, "**", "SKILL.md"), recursive=True):
    if ".archive" in f or ".curator_backups" in f or ".hub" in f:
        continue
    text = open(f, encoding="utf-8", errors="replace").read(2000)
    m = re.search(r"^name:\s*(\S+)", text, re.M)
    name = m.group(1) if m else os.path.basename(os.path.dirname(f))
    found[name] = f

usage = json.load(open(os.path.join(skills_root, ".usage.json")))

print("=== NE STANDARTNYE (net v bundled_manifest) ===")
for name in sorted(found):
    if name not in bundled:
        meta = usage.get(name, {})
        created = (meta.get("created_at") or "")[:10]
        by = meta.get("created_by") or "-"
        rel = found[name].replace(skills_root, "")
        print("{:<45} created={} by={}  {}".format(name, created, by, rel))

print()
print("=== V BUNDLE, NO created_by=agent/patched ===")
for name in sorted(found):
    if name in bundled:
        meta = usage.get(name, {})
        if meta.get("created_by") == "agent" or meta.get("last_patched_at"):
            rel = found[name].replace(skills_root, "")
            print("{:<45} patched={}  {}".format(name, str(meta.get("last_patched_at"))[:10], rel))
