#!/usr/bin/env python3
"""Interactive telnet CLI for KeeneticOS.

Handles Login:/Password: prompts, (config)> prompt, and --More-- paging.

Usage:
    KEEN_PASS=secret keen_telnet_cli.py "show version" "show interface" "show ip"
    KEEN_PASS=secret keen_telnet_cli.py  # default: show version + show interface

Env vars:
    KEEN_HOST (default 192.168.2.1), KEEN_USER (default admin), KEEN_PASS (required)

Plain `nc |` piping FAILS on Keenetic telnet (input races the prompt) — use this
socket-based waiter instead. To CHANGE settings, pass commands in sequence, e.g.:
    interface WifiMaster0
    channel 11
    exit
    system configuration save
"""
import socket
import time
import sys
import os
import select

HOST = os.environ.get("KEEN_HOST", "192.168.2.1")
PORT = 23
USER = os.environ.get("KEEN_USER", "admin")
PASS = os.environ.get("KEEN_PASS")

CMDS = sys.argv[1:] or ["show version", "show interface"]


def recv_until(sock, token, timeout=8):
    sock.setblocking(False)
    buf = b""
    end = time.time() + timeout
    while time.time() < end:
        r, _, _ = select.select([sock], [], [], 0.3)
        if r:
            try:
                data = sock.recv(4096)
            except BlockingIOError:
                continue
            if not data:
                break
            buf += data
            if token.lower().encode() in buf.lower():
                return buf
    return buf


def main():
    if not PASS:
        print("KEEN_PASS env var required", file=sys.stderr)
        sys.exit(2)
    s = socket.create_connection((HOST, PORT), timeout=10)
    s.settimeout(10)

    recv_until(s, "Login:")
    s.sendall((USER + "\r").encode())
    recv_until(s, "Password:")
    s.sendall((PASS + "\r").encode())
    out = recv_until(s, ">", timeout=10)
    print(out.decode(errors="replace"), end="")

    for cmd in CMDS:
        s.sendall((cmd + "\r").encode())
        full = b""
        while True:
            out = recv_until(s, ">", timeout=8)
            full += out
            low = out.lower()
            # paging: send space to continue
            if b"more" in low or b"--more--" in low or low.rstrip().endswith(b":"):
                s.sendall(b" ")
                time.sleep(0.3)
                continue
            break
        print(f"\n=== $ {cmd} ===")
        print(full.decode(errors="replace"))
    s.close()


if __name__ == "__main__":
    main()
