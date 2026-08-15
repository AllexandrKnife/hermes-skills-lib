#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Проверка статьи ВАК-формата после склейки (запускать ДО reviewer).

Использование:
    python3 verify_article.py <final/statya_N.txt> [data/results_N.txt]

Проверяет:
1. Ссылки [N] в тексте == позиции списка литературы (ГОСТ: каждая
   использована и определена; составные [5, 6] распарсиваются).
2. Цифры из results-файла присутствуют в статье (нормализация
   запятая<->точка, пробелы убраны) — ловит ручные опечатки.
3. Нет строк длиннее 80 (выключка/таблицы).
Exit 0 = чисто; 1 = есть проблемы.
"""
import re
import sys


def norm(s: str) -> str:
    return re.sub(r"\s", "", s.replace(",", "."))


def check_links(full: str) -> bool:
    body = full.split("СПИСОК ЛИТЕРАТУРЫ")[0]
    refs = full.split("СПИСОК ЛИТЕРАТУРЫ")[1]
    used = set()
    for grp in re.findall(r"\[(\d+(?:\s*,\s*\d+)*)\]", body):
        for n in re.findall(r"\d+", grp):
            used.add(int(n))
    defined = set(int(x) for x in re.findall(r"^\[(\d+)\]", refs, re.M))
    miss_def = sorted(used - defined)
    miss_use = sorted(defined - used)
    ok = not miss_def and not miss_use
    print(f"ссылки: использовано {len(used)}, определено {len(defined)} "
          f"{'OK' if ok else '-> НЕ сходятся: без определения ' + str(miss_def) + ', без использования ' + str(miss_use)}")
    return ok


def check_numbers(full: str, results_path: str) -> bool:
    if not results_path:
        return True
    calc = open(results_path, encoding="utf-8").read()
    # вытащить числа из расчёта (числа с десятичной точкой/запятой)
    nums = set()
    for m in re.findall(r"\d+[.,]\d+", calc):
        nums.add(m)
    bad = [n for n in nums if norm(n) not in norm(full)]
    ok = len(bad) == 0
    print(f"цифры из расчёта: {len(nums)} проверено, не в статье: {bad[:8] if bad else 'нет'} "
          f"{'OK' if ok else '-> ПРОВЕРИТЬ (могли быть округлены вручную)'}")
    return ok


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: verify_article.py <final/statya.txt> [data/results.txt]", file=sys.stderr)
        return 2
    full = open(sys.argv[1], encoding="utf-8").read()
    results = sys.argv[2] if len(sys.argv) > 2 else None
    ok = check_links(full)
    ok = check_numbers(full, results) and ok
    over = [ln for ln in full.split("\n") if len(ln) > 80]
    if over:
        ok = False
        print(f"строк >80: {len(over)} (первая: {over[0][:60]})")
    else:
        print("строк >80: 0 OK")
    print("ИТОГ:", "OK" if ok else "ЕСТЬ ПРОБЛЕМЫ")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
