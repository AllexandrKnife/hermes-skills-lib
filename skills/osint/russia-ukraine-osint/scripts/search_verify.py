#!/usr/bin/env python3
"""Батч-поиск и верификация для OSINT-отчётов (скилл russia-ukraine-osint).

Использование:
  python3 search_verify.py "запрос 1" "запрос 2" ...   # свои запросы
  python3 search_verify.py                              # usage

Требует: pip install ddgs   (ставится в системный python3)

ВАЖНО: установка ddgs в системный python НЕ чинит штатный web_search
Hermes (его бэкенд живёт в отдельном окружении). Пользуйтесь скриптом
напрямую — это и есть рабочий канал, проверен 02.08.2026.

Принципы:
- компактный вывод: title / href / body[:180] — чтобы не забивать контекст
- sleep 1.5s между запросами — DDG режет частые запросы
- при расхождении цифр между источниками — фиксировать ОБА значения
- для полного текста статьи: fetch_clean(url) — прямой curl с браузерным UA
  (Moscow Times отдаёт пустоту на прямой curl — брать сниппеты из выдачи;
  r.jina.ai из текущей сети отдаёт Unavailable For Legal Reasons — не ретраить)
"""
import html
import re
import subprocess
import sys
import time

from ddgs import DDGS

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0 Safari/537.36")


def ddgs_search(query, n=4):
    """Поиск по DDG через библиотеку ddgs. Возвращает список dict'ов."""
    with DDGS() as d:
        return list(d.text(query, max_results=n))


def fetch_clean(url):
    """Прямой curl + очистка HTML -> текст статьи (первые ~4500 символов)."""
    try:
        r = subprocess.run(
            ["curl", "-sL", "--max-time", "40", "-A", UA, url],
            capture_output=True, text=True, timeout=60,
        )
        t = r.stdout
    except Exception as e:
        return f"ERR {e}"
    if len(t) < 500:
        return "FETCH FAILED (len<500)"
    t = re.sub(r"<script.*?</script>", "", t, flags=re.S | re.I)
    t = re.sub(r"<style.*?</style>", "", t, flags=re.S | re.I)
    t = re.sub(r"<[^>]+>", " ", t)
    t = html.unescape(t)
    return re.sub(r"\s+", " ", t)[:4500]


def main():
    queries = sys.argv[1:]
    if not queries:
        print(__doc__)
        return
    for q in queries:
        print("=" * 100)
        print("Q:", q)
        try:
            for x in ddgs_search(q):
                print(" -", (x.get("title") or "")[:90].replace("\n", " "))
                print("   ", x.get("href") or "")
                print("   ", (x.get("body") or "")[:180].replace("\n", " "))
        except Exception as e:
            print("  ERR:", e)
        time.sleep(1.5)


if __name__ == "__main__":
    main()
