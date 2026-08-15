#!/usr/bin/env python3
"""CORS HTTP-сервер: раздача файлов (прошивок) в браузерную сессию роутера.

Зачем: file-input в веб-морде роутера программно не заполнить, а curl-сессия
часто лочится. Трюк: авторизованный браузер на роутере fetch'ит файл с этого
сервера (Access-Control-Allow-Origin: *) и POST'ит его FormData в
upgrade-эндпоинт роутера.

Запуск (фон):  python3 cors-server.py [DIR] [PORT]
По умолчанию:  /root/cudy-wr3000s-kit/firmware : 8000
Проверка:      curl -s -H "Origin: http://<роутер>" http://<WSL-IP>:8000/<файл>
"""
import http.server, sys, os

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
