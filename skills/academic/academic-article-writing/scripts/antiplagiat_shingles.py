#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Локальный антиплагиат шинглами (10 слов): self, cross, корпус автора.

Запуск: python3 antiplagiat_shingles.py <папка-статей> [корпус-автора]
Методика — стандартная для антиплагиата: нормализация (нижний регистр,
только буквы/цифры), окна по 10 слов, пересечения множеств.
ЛЕГИТИМНЫЕ пересечения (не плагиат): титульный блок (ФИО/должность/институт),
одинаковая фирменная фраза серии, библиография (общие источники).
"""
import hashlib, os, re, sys

def normalize(t):
    t = t.lower()
    t = re.sub(r"[^а-яёa-z0-9\s]", " ", t)
    return re.sub(r"\s+", " ", t).strip()

def shingles(text, n=10):
    w = normalize(text).split()
    return [" ".join(w[i:i + n]) for i in range(len(w) - n + 1)]

def report(arts_dir, corpus_dir=None):
    arts = {fn: open(os.path.join(arts_dir, fn), encoding="utf-8").read()
            for fn in sorted(os.listdir(arts_dir)) if fn.endswith(".txt")}
    print("=== 1. ПОВТОРЫ ВНУТРИ СТАТЕЙ (self) ===")
    for fn, t in arts.items():
        w = normalize(t).split()
        seen = {}
        for i in range(len(w) - 9):
            sh = " ".join(w[i:i + 10])
            seen[sh] = seen.get(sh, 0) + 1
        dups = sum(1 for v in seen.values() if v > 1)
        uniq = len(seen)
        total = len(w) - 9
        print(f"{fn}: уникальность окон {uniq/total*100:.1f}% (дублей {dups})")
    print("\n=== 2. ПЕРЕСЕЧЕНИЯ МЕЖДУ СТАТЬЯМИ ===")
    names = list(arts)
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            a, b = names[i], names[j]
            hits = [s for s in shingles(arts[b]) if s in set(shingles(arts[a]))]
            tb = len(shingles(arts[b]))
            print(f"{a[:22]} vs {b[:22]}: {len(hits)} окон ({len(hits)/tb*100:.1f}% текста B)")
    if corpus_dir:
        print("\n=== 3. СОВПАДЕНИЯ С КОРПУСОМ АВТОРА ===")
        corpus = ""
        for f in os.listdir(corpus_dir):
            if f.endswith(".txt"):
                corpus += open(os.path.join(corpus_dir, f), encoding="utf-8").read() + "\n"
        cset = set(shingles(corpus))
        for fn, t in arts.items():
            hits = [s for s in shingles(t) if s in cset]
            tot = len(shingles(t))
            print(f"{fn}: {len(hits)} ({len(hits)/tot*100:.1f}%) — обычно это ФИО и библиография")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python3 antiplagiat_shingles.py <папка> [папка-корпуса]", file=sys.stderr)
        sys.exit(2)
    report(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
