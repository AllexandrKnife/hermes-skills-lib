#!/usr/bin/env python3
"""Direct Exa MCP search via curl (bypasses Cloudflare JA3 filtering of urllib).

Works when mcp__exa__* tools are not loaded into the current Hermes session
or when the MCP client has no proxy env and the direct IP is CF-blocked.
Honors http_proxy/https_proxy env vars from the shell (curl does).

Usage:
    python3 exa-mcp-direct.py "query text" [num_results]
"""
import json, subprocess, sys

URL = "https://mcp.exa.ai/mcp"

def curl_post(body: dict) -> str:
    r = subprocess.run(
        ["curl", "-s", "-m", "45", "-X", "POST", URL,
         "-H", "Content-Type: application/json",
         "-H", "Accept: application/json, text/event-stream",
         "-d", json.dumps(body)],
        capture_output=True, text=True, timeout=60)
    return r.stdout

def parse_sse(raw):
    for line in raw.splitlines():
        if line.startswith("data: "):
            try:
                yield json.loads(line[6:])
            except json.JSONDecodeError:
                pass

def search(query, num=5):
    curl_post({"jsonrpc": "2.0", "id": 1, "method": "initialize",
               "params": {"protocolVersion": "2025-03-26", "capabilities": {},
                          "clientInfo": {"name": "hermes-direct", "version": "1.0"}}})
    curl_post({"jsonrpc": "2.0", "id": 2, "method": "notifications/initialized", "params": {}})
    raw = curl_post({"jsonrpc": "2.0", "id": 3, "method": "tools/call",
                     "params": {"name": "web_search_exa",
                                "arguments": {"query": query, "numResults": num}}})
    for msg in parse_sse(raw):
        if "result" in msg:
            for c in msg["result"].get("content", []):
                if c.get("type") == "text":
                    return c["text"]
    return raw[:2000]

if __name__ == "__main__":
    q = sys.argv[1] if len(sys.argv) > 1 else "test"
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    print(search(q, n))
