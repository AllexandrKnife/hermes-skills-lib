#!/usr/bin/env python3
"""Мини HTTP-сервер с CORS для раздачи файлов в авторизованную браузерную сессию
(загрузка прошивки/файлов в веб-формы роутеров, где curl блокируется, а file-input
JS-ом не заполнить). Запуск: python3 cors-server.py [порт] [директория].
Проверка: curl -H "Origin: http://<router-ip>" http://<wsl-ip>:8000/<file>"""
import http.server, os, sys

DIR = os.environ.get('CORS_DIR', '/root/cudy-wr3000s-kit/firmware')
PORT = int(os.environ.get('CORS_PORT', '8000'))

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
    if len(sys.argv) > 1:
        PORT = int(sys.argv[1])
    if len(sys.argv) > 2:
        DIR = sys.argv[2]
    print(f"serving {DIR} on :{PORT}", flush=True)
    http.server.ThreadingHTTPServer(('0.0.0.0', PORT), H).serve_forever()
