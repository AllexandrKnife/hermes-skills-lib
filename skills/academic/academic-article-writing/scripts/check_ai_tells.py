#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Механический детектор артефактов ИИ в тексте статьи (ВАК, рус/англ).

Запуск: python3 check_ai_tells.py <файл-статьи>
Методика — паттерны humanizer (34) + русский словарь канцелярита.
КРИТЕРИЙ: единичные канцеляритные обороты («в свою очередь», «таким образом»,
«в целом») — НОРМА научного стиля, не артефакт; артефакт = злоупотребление
(многократные повторы), англ. AI-слова в ABSTRACT, -ing-хвосты, правило трёх.
"""
import os, re, sys

RU_MARKERS = [
    "в современном мире", "в современных условиях", "сегодня как никогда",
    "стоит отметить", "следует отметить", "важно подчеркнуть", "необходимо отметить",
    "в свою очередь", "таким образом", "в заключение",
    "актуальность темы обусловлена", "на сегодняшний день", "на данный момент",
    "широкий спектр", "комплексный подход", "многообразие аспектов",
    "вышеуказанный", "нижеследующий", "Безусловно", "Стоит задуматься",
]
EN_MARKERS = [
    "additionally", "crucial", "delve", "emphasiz", "enduring", "enhanc", "foster",
    "garner", "highlight", "interplay", "intricate", "pivotal", "showcase",
    "tapestry", "testament", "underscore", "vibrant", "moreover", "furthermore",
    "groundbreaking", "seamless", "in today", "ever-evolving", "landscape",
    "it's not just", "at the end of the day", "game-changer", "deep dive",
]
ING_TAIL = re.compile(r",\s*(highlighting|underscoring|emphasizing|reflecting|"
                      r"symbolizing|showcasing|ensuring|fostering)\b")
DANNY = re.compile(r"\bданн(ый|ая|ое|ом|ой|ого|ым|ыми|ую|ых)\b")
NOI = re.compile(r"\bно\s+и\b")

def check(path):
    t = open(path, encoding="utf-8").read()
    norm = re.sub(r"\s+", " ", t)
    low = norm.lower()
    print("=" * 70)
    print(os.path.basename(path))
    dash = t.count("—")
    print(f"  Эм-даши: {dash} ({dash/(len(t)/1000):.1f}/1000 симв; норма 1-3)")
    for m in RU_MARKERS:
        c = low.count(m)
        if c:
            i = low.find(m)
            print(f"  [RU] '{m}' x{c}: ...{norm[max(0,i-50):i+len(m)+50]}...")
    for m in EN_MARKERS:
        c = low.count(m)
        if c:
            i = low.find(m)
            print(f"  [EN] '{m}' x{c}: ...{norm[max(0,i-50):i+len(m)+50]}...")
    for m in ING_TAIL.finditer(norm):
        print(f"  [ING-tail] ...{m.group(0)[-40:]}...")
    for m in DANNY.finditer(norm):
        i = m.start()
        print(f"  [данный] ...{norm[max(0,i-45):i+45]}...")
    for m in NOI.finditer(low):
        i = m.start()
        print(f"  [но и] ...{norm[max(0,i-45):i+45]}...")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python3 check_ai_tells.py <file>", file=sys.stderr)
        sys.exit(2)
    check(sys.argv[1])
