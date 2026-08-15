#!/usr/bin/env python3
"""Мини HTTP-сервер с CORS для передачи файлов в браузерную сессию (обход нативного file-picker).

Зачем: браузерные инструменты не умеют подставлять файл в input[type=file].
Вместо этого — раздать файл с WSL с заголовком Access-Control-Allow-Origin: *,
а в авторизованной странице роутера через browser_console сделать:
    fetch('http://<wsl-ip>:8000/file.bin') -> blob -> FormData -> POST в форму роутера
(same-origin POST сам подставит cookie сессии).

Использование:
    python3 cors-file-server.py [DIR] [PORT]
        DIR  — каталог с файлами (default: /root/cudy-wr3000s-kit/firmware)
        PORT — порт (default: 8000)
    WSL IP: ip -4 addr show eth0 | grep -oE 'inet [0-9.]+'
"""
import http.server
import os
import sys

DIR = sys.argv[1] if len(sys.argv) > 1 else '/root/cudy-wr3000s-kit/firmware'
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8000


class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=DIR, **kw)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write(f"[cors-srv] {self.client_address[0]} {fmt % args}\n")


if __name__ == '__main__':
    print(f"serving {DIR} on :{PORT}", flush=True)
    http.server.ThreadingHTTPServer(('0.0.0.0', PORT), H).serve_forever()
