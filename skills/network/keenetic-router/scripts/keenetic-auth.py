#!/usr/bin/env python3
"""
Keenetic NDMS v3.x RCI Authentication Helper

Usage:
  python3 keenetic-auth.py <router_ip> <login> <password>

Output:
  Prints "AUTH_OK" on success, "AUTH_FAIL" on failure.
  Creates /tmp/keenetic_cookies.txt for subsequent RCI queries.
  Creates /tmp/keenetic_headers.txt with the last response headers.
"""

import hashlib, subprocess, sys, os, json

def authenticate(router_ip, login, password):
    cookie_jar = "/tmp/keenetic_cookies.txt"
    header_file = "/tmp/keenetic_headers.txt"
    
    # Clean previous session
    for f in [cookie_jar, header_file]:
        if os.path.exists(f):
            os.remove(f)
    
    # Step 1: GET /auth — get challenge + session cookie
    cmd1 = f'curl -s --max-time 10 -c "{cookie_jar}" -D "{header_file}" "http://{router_ip}/auth"'
    r1 = subprocess.run(cmd1, shell=True, capture_output=True, text=True, timeout=10)
    
    # Parse challenge and realm from headers
    challenge = None
    realm = None
    with open(header_file) as f:
        for line in f:
            if "X-NDM-Challenge:" in line:
                challenge = line.split(":", 1)[1].strip()
            if "X-NDM-Realm:" in line:
                realm = line.split(":", 1)[1].strip()
    
    if not challenge or not realm:
        # Could be already authenticated
        return True, "AUTH_OK (already authenticated?)"
    
    # Step 2: Compute SHA-256(challenge + MD5(login:realm:password))
    step1 = hashlib.md5(f"{login}:{realm}:{password}".encode()).hexdigest()
    step2 = hashlib.sha256((challenge + step1).encode()).hexdigest()
    
    # Step 3: POST /auth with the hash
    data = json.dumps({"login": login, "password": step2})
    cmd2 = (
        f'curl -s --max-time 10 -X POST "http://{router_ip}/auth" '
        f'-H "Content-Type: application/json" '
        f'-b "{cookie_jar}" -c "{cookie_jar}" '
        f'-d \'{data}\' -o "{header_file}" '
        f'-w "%{{http_code}}"'
    )
    r2 = subprocess.run(cmd2, shell=True, capture_output=True, text=True, timeout=10)
    http_code = r2.stdout.strip()
    
    if http_code == "200":
        return True, f"AUTH_OK (HTTP {http_code})"
    else:
        return False, f"AUTH_FAIL (HTTP {http_code})"

def rci_query(router_ip, payload):
    """Execute an RCI query after authentication."""
    cookie_jar = "/tmp/keenetic_cookies.txt"
    if not os.path.exists(cookie_jar):
        return {"error": "Not authenticated. Run authenticate() first."}
    
    cmd = (
        f'curl -s --max-time 10 -X POST "http://{router_ip}/rci/" '
        f'-H "Content-Type: application/json" '
        f'-b "{cookie_jar}" '
        f'-d \'{json.dumps(payload)}\''
    )
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"raw": r.stdout}

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: keenetic-auth.py <ip> <login> <password>")
        sys.exit(1)
    
    ip, login, password = sys.argv[1], sys.argv[2], sys.argv[3]
    success, msg = authenticate(ip, login, password)
    print(msg)
    sys.exit(0 if success else 1)
