#!/usr/bin/env python3
"""Authenticate to KeeneticOS web API (x-ndw2-interactive challenge-response).

Algorithm (reverse-engineered from the SPA bundle, getEncryptedPassword):
    GET /auth  -> 401, headers X-NDM-Challenge / X-NDM-Realm + Set-Cookie session
    d   = MD5("login:realm:password").hexdigest()
    enc = SHA256(challenge + d).hexdigest()
    POST /auth {"login": login, "password": enc} with cookie jar -> 200 + session cookie

Usage:
    KEEN_PASS=secret keen_api_auth.py [cookie_file]

Env vars:
    KEEN_HOST (default 192.168.2.1), KEEN_USER (default admin), KEEN_PASS (required)

Pitfalls:
    - Plaintext password -> 400 Bad Request.
    - Dropping the session cookie between GET and POST -> 400 (X-Detail: 0x2021, no session).
    - GET / (panel root) does NOT issue the session cookie — use GET /auth.
"""
import hashlib
import urllib.request
import urllib.error
import http.cookiejar
import json
import os
import sys

base = "http://" + os.environ.get("KEEN_HOST", "192.168.2.1")
login = os.environ.get("KEEN_USER", "admin")
passw = os.environ.get("KEEN_PASS")
cookie_file = sys.argv[1] if len(sys.argv) > 1 else "/tmp/keen_cookies.txt"

if not passw:
    print("KEEN_PASS env var required", file=sys.stderr)
    sys.exit(2)

cj = http.cookiejar.MozillaCookieJar(cookie_file)
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

req = urllib.request.Request(base + "/auth", method="GET")
try:
    opener.open(req)
except urllib.error.HTTPError as e:
    chal = e.headers["X-NDM-Challenge"]
    realm = e.headers["X-NDM-Realm"]

d = hashlib.md5(f"{login}:{realm}:{passw}".encode()).hexdigest()
enc = hashlib.sha256((chal + d).encode()).hexdigest()

req = urllib.request.Request(
    base + "/auth",
    method="POST",
    data=json.dumps({"login": login, "password": enc}).encode(),
)
req.add_header("Content-Type", "application/json")
try:
    opener.open(req)
    print("AUTH OK | challenge:", chal, "| realm:", realm)
except urllib.error.HTTPError as e:
    print("AUTH FAIL", e.code, e.read()[:200], file=sys.stderr)
    sys.exit(1)

try:
    cj.save(ignore_discard=True, ignore_expires=True)
except Exception:
    pass
print("session cookies:", [c.name for c in cj])
print("cookie jar:", cookie_file)
