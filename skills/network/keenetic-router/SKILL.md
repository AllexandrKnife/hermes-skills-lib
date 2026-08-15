---
name: keenetic-router
description: "Manage Keenetic NDMS routers (KN-1210 / 4G) via RCI API — challenge-response auth, configuration queries, WireGuard VPN, policies, WiFi, and system management."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [Keenetic, Router, NDMS, RCI, WireGuard, VPN, Network, Sysadmin]
    related_skills: [wsl-maintenance, windows-wifi-diagnostics]
---

# Keenetic Router — RCI API Management

Manage Keenetic NDMS routers via the RCI (Remote Configuration Interface) API. Covers the challenge-response auth mechanism, common configuration queries, and WireGuard VPN management.

Tested on **Keenetic 4G (KN-1210)** running **NDMS 3.07.C.5.0-0** (Oct 2022).

## When to Use

- User asks to check/configure their Keenetic router
- User wants VPN setup (WireGuard, OpenVPN) on a Keenetic
- User needs port forwarding, WiFi config, or security audit of their Keenetic
- Any router management task on a Keenetic NDMS device

> **Reference profile:** See `references/live-router-profile-kn1730.md` for a real-world Keenetic-1730 on KeeneticOS 4.03.C.6.2-7 with 4G modem + 5 WireGuard tunnels.

## Prerequisites

- Router IP (default: `192.168.1.1`)
- Credentials (login + password)
- `curl` available on the system
- Network access to the router

## Challenge-Response Authentication (CRITICAL)

Keenetic NDMS v3.x uses a proprietary challenge-response auth, NOT basic auth or simple POST:

### Auth Flow (reverse-engineered from angular-md5 + ngSha JS)

```
GET  /auth  →  receive challenge + realm + session cookie
POST /auth  →  send SHA-256(challenge + MD5(login:realm:password))
```

### Python Implementation

```python
import hashlib, subprocess

# Step 1: GET /auth — get challenge + session
r = subprocess.run(
    "curl -s -c /tmp/router_cookies.txt -D /tmp/router_headers.txt http://192.168.1.1/auth",
    shell=True, capture_output=True, text=True, timeout=10
)

# Parse challenge and realm from response headers
challenge = realm = None
with open("/tmp/router_headers.txt") as f:
    for line in f:
        if "X-NDM-Challenge:" in line:
            challenge = line.split(":", 1)[1].strip()
        if "X-NDM-Realm:" in line:
            realm = line.split(":", 1)[1].strip()

# Step 2: Compute the hash
step1 = hashlib.md5(f"{login}:{realm}:{password}".encode()).hexdigest()  # lowercase hex
step2 = hashlib.sha256((challenge + step1).encode()).hexdigest()          # lowercase hex

# Step 3: POST /auth with the hash
data = '{{"login":"{0}","password":"{1}"}}'.format(login, step2)
subprocess.run(
    f'curl -s -X POST http://192.168.1.1/auth '
    f'-H "Content-Type: application/json" '
    f'-b /tmp/router_cookies.txt -c /tmp/router_cookies.txt '
    f'-d \'{data}\'',
    shell=True, timeout=10
)
```

### Algorithm Details

The AngularJS code reveals the exact algorithm:

```javascript
// authenticationService factory (minified):
// $sha = SHA-256 (default algorithm from ngSha module)
// md5 = angular-md5 module
// $sha.config = { algorithm: "SHA-256", inputType: "TEXT", returnType: "HEX" }

authenticate: function(login, password) {
    var r = $sha.hash(token + md5.createHash(login + ":" + realm + ":" + password));
    return $http.post("/auth", {login: login, password: r}, {timeout: 15000});
}
```

- `$sha.hash(string)` defaults to **SHA-256** with TEXT input and HEX output (lowercase)
- `md5.createHash(string)` returns **lowercase hex** MD5
- `token` = `X-NDM-Challenge` header value from the GET /auth 401 response
- `realm` = `X-NDM-Realm` header value

### Response Headers Reference

| Header | Example | Description |
|--------|---------|-------------|
| `X-NDM-Challenge` | `BQMFGNIWXKRZOKCOPJTOKBDKAKNDMZDP` | Random challenge string (changes per request) |
| `X-NDM-Realm` | `Keenetic 4G` | Realm for password hashing |
| `WWW-Authenticate` | `x-ndw2-interactive realm="..." challenge="..." session_id="..."` | Full auth info |
| `Set-Cookie` | `VFSKBXMLYAN=<session_id>; Path=/` | Session cookie |

### Cookie Notes

- The cookie name (`VFSKBXMLYAN` in example) is **random** — changes per session
- The cookie value = `session_id` from the WWW-Authenticate header
- Must send the cookie with the POST /auth request

## Common RCI Queries

All queries are POST to `http://<router-ip>/rci/` with JSON body. Requires authenticated session cookie.

### System Info

```json
{"show": {"system": {}}}
```
Returns: hostname, uptime, cpuload, memory, swap

### Version / Model

```json
{"show": {"version": {}}}
```
Returns: firmware release, model (e.g. "4G (KN-1210)"), arch, components list

### Internet Status

```json
{"show": {"internet": {"status": {}}}}
```
Returns: connection status, gateway IP, DNS accessibility

### Interface List

```json
{"show": {"interface": {}}}
```
Returns: all physical + virtual interfaces (FastEthernet, Bridge, Vlan, etc.)
**Note:** WireGuard and VPN interfaces may NOT appear in this list. Query routing tables instead.

### All Interfaces (verbose)

```json
{"show": {"interface": "all"}}
```

### Routing Table

```json
{"show": {"ip": {"route": {}}}}
```
Returns: all routes (destination, gateway, interface, metric)

### Routing Table by Table ID

```json
{"show": {"ip": {"route": {"table": 42}}}}
```
Useful for VPN policy-based routing tables.

### IP Policies (PBR — Policy Based Routing)

```json
{"show": {"ip": {"policy": {}}}}
```
Returns: all policies with description, mark, table ID, and routes. This is how WireGuard / VPN routing rules are configured on Keenetic.

### DHCP Leases / Connected Clients

```json
{"show": {"ip": {"hotspot": {}}}}
```
Returns: DHCP hosts with MAC, IP, hostname, lease status

### DNS Servers

```json
{"show": {"ip": {"name-server": {}}}}
```

### Users / Admin Accounts

```json
{"show": {"rc": {"user": {}}}}
```
Returns: user list with password hashes (MD5 + NT) and tags (cli, http, readonly)

### Web Interface Security

```json
{"show": {"rc": {"ip": {"http": {}}}}}
```
Returns: port, security-level (public/private), SSL settings, lockout policy

### DDNS (Keendns)

```json
{"show": {"ndns": {}}}
```
Returns: DDNS hostname, domain, last updated status

## WireGuard VPN Configuration

On Keenetic NDMS, WireGuard is configured as:
1. A **virtual interface** (e.g., `Wireguard1`)
2. **IP policy** (PBR) that routes selected traffic through the tunnel

### Key RCI Endpoints

| Purpose | Query |
|---------|-------|
| All policies | `{"show":{"ip":{"policy":{}}}}` |
| Specific policy | `{"show":{"ip":{"policy":"Policy1"}}}` |
| All routes | `{"show":{"ip":{"route":{}}}}` |
| Routes in VPN table | `{"show":{"ip":{"route":{"table":42}}}}` |

### WireGuard Architecture (discovered)

```
Wireguard1 (10.77.77.0/24)        — WG virtual interface + subnet
  └─ External endpoint: <IP>       — VPN provider server

Policy1 ("VPN NL")                 — policy-based routing rule
  ├─ table: 42                     — isolated routing table
  ├─ mark: 0xffffd00               — fwmark for policy routing
  ├─ route 0.0.0.0/0 → Wireguard1  — full tunnel (all traffic)
  ├─ route 10.77.77.0/24 → WG1     — local WG subnet via tunnel
  ├─ route 10.1.30.0/24 → Guest    — guest network via ISP (bypass VPN)
```

### WG Client vs Server

- **Client mode:** WG interface connects to an external VPN provider endpoint
- **Server mode:** WG interface listens for incoming connections from remote peers
- Policy routing determines which traffic goes through the tunnel
- The RCI API `show` endpoints for `wireguard` and `wg` return "not found" — WG config details are not directly exposed via RCI. Use the telnet CLI to view full WG config (keys, allowed IPs, endpoints)

## WiFi Channel Configuration (telnet CLI)

On KeeneticOS NDMS 3.x, the **WiFi channel dropdown is greyed out** in the web UI when **auto-channel selection** is active (no explicit `channel` set in running-config). The channel CANNOT be set via RCI `set`/`apply`/`configure` — those endpoints return "not found" errors. The ONLY reliable way is via the telnet CLI.

### Step-by-Step: Change WiFi Channel via Telnet

```bash
# Connect
telnet 192.168.1.1 23

# Login
Login: admin
Password: ********

# Enter interface config mode for the 2.4 GHz radio
(config)> interface WifiMaster0
Core::Configurator: Done.
(config-if)>

# Set the channel (e.g. 6)
(config-if)> channel 6
Network::Interface::Rtx::WifiMaster: "WifiMaster0": channel set to 6.

# Exit back to config mode
(config-if)> exit
Core::Configurator: Done.
(config)>

# (Optional) Verify the change via RCI in another terminal:
# {"show": {"interface": {}}}
# Look for WifiMaster0 → channel field
```

### Channel Width

The running-config shows the width setting:
```
interface WifiMaster0
    channel width 40-below
```

| Width | Value | Notes |
|-------|-------|-------|
| `40-below` | 40 MHz, extension channel BELOW control | Use when control channel is 5+ (e.g. ch6 → ext ch2) |
| `40-above` | 40 MHz, extension channel ABOVE control | Use when control channel is 1-5 (e.g. ch1 → ext ch5) |
| `20` | 20 MHz only | Caps speed at ~72 Mbps |

On channel 1, `40-below` is suboptimal because extension channel -1 doesn't exist — effectively forces HT20 operation. After moving to channel 6, change width:
```bash
(config-if)> channel width 40-above
```

### Compatibility (Radio Mode)

```
interface WifiMaster0
    compatibility BGN  # 802.11 b/g/n — all legacy
```

| Value | Meaning |
|-------|---------|
| `BGN` | 802.11b/g/n — full backward compatibility (default) |
| `GN` | 802.11g/n — drops b (slightly less overhead) |
| `N` | 802.11n only — pure mode, max speed if all clients support it |
| `B` | 802.11b only — legacy only |

Note: changing `compatibility` away from BGN may disconnect older devices (IoT, old phones, etc.).

### Country Code

```
interface WifiMaster0
    country-code RU
```

The country code determines which channels and power levels are legal. In Russia (RU), channels 1-13 are available with up to 20 dBm (100 mW) EIRP.

### Auto-Channel Detection

If the running-config has **no** `channel` line under `WifiMaster0`, the router is in **auto-channel selection mode** — the web UI dropdown will be greyed/disabled. Adding an explicit `channel X` via telnet overrides auto and enables manual control.

### Verify the Change

After setting the channel, query via RCI:
```bash
curl -s -X POST http://192.168.1.1/rci/ \
  -H "Content-Type: application/json" \
  -b /tmp/keenetic_cookies.txt \
  -d '{"show":{"interface":{}}}'
```

Look for `WifiMaster0` → `"channel": 6` in the response.

### Windows Client Verification

From WSL/Windows:
```bash
netsh.exe wlan show interface | findstr Channel
# or with English locale:
powershell.exe -Command "[System.Globalization.CultureInfo]::CurrentUICulture='en-US'; netsh wlan show interface | Select-String Channel"
```

### Full Channel Congestion Scan

To analyze surrounding networks and pick the best channel before making changes, scan from Windows:

```bash
netsh.exe wlan show networks mode=bssid
```

See `windows-wifi-diagnostics` skill → `references/channel-scan-analysis.md` for a real-world scan example with congestion map, recommendations, and predicted gains.

## Telnet / CLI Reference

Connect: `telnet 192.168.1.1 23`

### Login
```
Login: admin
Password: ****
```

The prompt shows: `(config)>` — this is the standard CLI mode.

### Authentication Timing (CRITICAL on 4.x)

KeeneticOS **4.x** forcefully closes the telnet connection (`Connection closed by foreign host`) if credentials aren't sent promptly after the banner. Pressing Enter at the `Login:` prompt without sending credentials immediately may also trigger closure.

**Symptom:** `telnet 192.168.1.1` → `Connected` → `Connection closed by foreign host` in under 1 second.

**Fix — Python telnetlib with batch send:**

```python
import telnetlib, time, re

tn = telnetlib.Telnet("192.168.1.1", 23, timeout=15)
time.sleep(2)                     # wait for banner
tn.read_very_eager()              # consume banner
tn.write(b"admin\n")              # send username
time.sleep(0.3)
tn.write(b"1qsxdrgb\n")           # send password immediately after
time.sleep(2)
tn.read_very_eager()              # consume auth response
# Now at (config)> prompt
```

The key is sending username + password in **quick succession** with minimal delay between them. The banner arrives in the initial read, then both credentials go out together.

### Enhanced Session Wrapper (for interactive queries)

```python
def keenetic_telnet(host, username, password, commands):
    tn = telnetlib.Telnet(host, 23, timeout=15)
    time.sleep(2)
    tn.read_very_eager()               # consume banner
    tn.write(f"{username}\n".encode())
    time.sleep(0.3)
    tn.write(f"{password}\n".encode())
    time.sleep(2)
    tn.read_very_eager()               # consume "(config)>" prompt
    results = {}
    for cmd in commands:
        tn.write(f"{cmd}\n".encode())
        time.sleep(2)
        data = tn.read_very_eager().decode("utf-8", errors="replace")
        clean = re.sub(r"\x1b\[[0-9;]*[K]", "", data).replace("\r\n", "\n")
        results[cmd] = clean
    tn.close()
    return results
```

### KeeneticOS 4.x Differences from 3.x

| Feature | NDMS 3.x | NDMS 4.x (4.03.C.6.2-7+) |
|---------|----------|--------------------------|
| Telnet auth timeout | Lenient | **Strict** — must send credentials quickly |
| `show running-config \| no-more` | Works | Returns `incorrect request` error |
| `enable` / `configure terminal` | Not available | Still not available (direct to `(config)>`) |
| WireGuard interfaces in `show interface` | Last in list | Same — last in list |
| `show system` fields | Same format | Same format (cpu, memory, uptime, conn) |
| `show ip route` output | Table format | Same table format |
| 4G modem info in `show interface` | Via `CdcEthernet<N>` | Same — CdcEthernet0 |
| Python telnetlib `read_very_eager()` | Works | **Beware:** no `timeout` kwarg accepted — use `time.sleep()` before calling |

## Traffic Shaping (`traffic-shape rate`)

Limit bandwidth on an interface directly from config mode:

```
(config)> interface Bridge1
Core::Configurator: Done.
(config-if)> traffic-shape rate 5120
(config-if)> exit
```

The rate is in **kbps**. Example: `5120` = 5 Mbps. Confirmed working on KeeneticOS 4.03.C.6.2-7.

To **verify** current traffic-shape settings, check `show running-config` and grep for `traffic-shape`.

## IP Hotspot — Client-to-Policy Bindings

Keenetic uses `ip hotspot` to assign specific clients (by MAC) to specific VPN policies. This overrides global routing and pins a device to a particular Wireguard tunnel.

### View Current Bindings

```bash
# Via CLI:
(config)> show running-config
# Look for "ip hotspot" and "host <mac> policy" lines

# Or in show mode:
(show)> interface
# ... look for hotspot section
```

### Running-Config Pattern

```
ip hotspot
    policy Home permit
    host 8c:16:45:90:44:d4 permit
    host 8c:16:45:90:44:d4 policy Policy3
    host 8c:16:45:90:44:d4 priority 3
    host 32:9f:5f:5c:de:d2 permit
    host 32:9f:5f:5c:de:d2 policy Policy4
    host 32:9f:5f:5c:de:d2 priority 3
    host b0:fc:36:5e:ca:db permit
    host b0:fc:36:5e:ca:db priority 3
```

### Elements

| Directive | Meaning |
|-----------|---------|
| `policy Home permit` | Default LAN policy allows all |
| `host <mac> permit` | Client is allowed on the network |
| `host <mac> policy PolicyN` | **Route all traffic from this MAC through this policy** |
| `host <mac> priority N` | Priority (1-7, higher = more bandwidth priority) |

### Priority Levels

- **1:** Lowest (background traffic)
- **3:** Medium (default for assigned clients)
- **7:** Highest (real-time / latency-sensitive)

Setting a `priority` without a `policy` limits the client's bandwidth priority on the default route. Setting BOTH `policy` + `priority` pins the client to a specific VPN AND gives it a bandwidth class.

## CLI Config Mode Reference

When entering `interface <name>` at the config prompt, you enter **interface configuration mode**:
```
(config)> interface WifiMaster0
Core::Configurator: Done.
(config-if)>           ← now in interface config
(config-if)> exit
Core::Configurator: Done.
(config)>               ← back to root config
```

### Interface Sub-Commands (available at `(config-if)>` prompt)

After entering `interface <name>` at config mode, the following sub-commands are available:

| Command | Scope | Description |
|---------|-------|-------------|
| `traffic-shape rate <kbps>` | any | Set bandwidth limit in kbps (e.g., `5120` = 5 Mbps) |
| `traffic-counter` | any | Configure traffic counter (bytes/packets tracking) |
| `tx-queue` | any | Set TX queue parameters (length, priority) |
| `mobile` | CdcEthernet only | Configure mobile network parameters (APN, auth) |
| `sim` | CdcEthernet only | Configure SIM parameters (PIN, slot) |
| `usb` | CdcEthernet only | Configure USB device parameters |
| `channel <N>` | WifiMaster only | Set WiFi channel override |
| `channel width <20\|40-below\|40-above>` | WifiMaster only | Set WiFi channel width |
| `compatibility <BGN\|GN\|N>` | WifiMaster only | Set WiFi radio mode |
| `country-code <XX>` | WifiMaster only | Set regulatory domain |
| `wireguard peer <pubkey>` | Wireguard only | Configure WireGuard peer (endpoint, keepalive, allowed-ips) |
| `wireguard asc <9 params>` | Wireguard only | Set AmneziaWG ASC obfuscation parameters (4.x+) |
| `up` / `down` | any | Enable/disable the interface |
| `description <text>` | any | Set human-readable description |
| `ip address <ip/mask>` | any | Set static IP or DHCP |
| `ip mtu <bytes>` | any | Set MTU size |
| `ip global <priority>` | any | Set interface priority for default route selection |
| `ip tcp adjust-mss pmtu` | any | Enable TCP MSS clamping based on PMTU |
| `security-level <public\|private>` | any | Set security zone |
| `ping-check profile <name>` | any | Enable ping health check |
| `?` | any | List all available sub-commands for this interface type |

Some sub-commands enter further sub-modes (e.g., `mobile` → `(config-if-mobile)>`, `wireguard peer` → `(config-if-wg-peer)>`). Use `?` at each level and `exit` to go back up.

### Available CLI Commands (discovered on NDMS 3.x, confirmed on 4.03.C.6.2-7)

| Command | Mode | Description |
|---------|------|-------------|
| `show version` | any | Firmware release, model, arch, components |
| `show system` | any | Hostname, uptime, CPU load, memory |
| `show interface` | any | All interfaces with status and details |
| `show ip route` | any | Routing table (default routes + VPN) — shows destination, gateway, interface, metric |
| `show running-config` | any | Full running configuration (4.x: do NOT use `| no-more` — returns error) |
| `show running-config interface <name>` | any | Running config for a specific interface |
| `show ip hotspot` | any | View client-to-policy bindings, MAC addresses, assigned policies and priorities |
| `show ip policy` | any | Policy-based routing rules (Policy0–PolicyN with marks, tables, routes) |
| `interface <name>` | config | Enter interface config mode (e.g., `WifiMaster0`, `Wireguard1`) |
| `channel <N>` | if-config | Set WiFi channel (e.g., `channel 6`) — only on `WifiMaster0` |
| `channel width <20\|40-below\|40-above>` | if-config | Set WiFi channel width — only on `WifiMaster0` |
| `compatibility <BGN\|GN\|N>` | if-config | Set WiFi radio mode — only on `WifiMaster0` |
| `country-code <XX>` | if-config | Set regulatory domain (e.g., `RU`, `US`) — only on `WifiMaster0` |
| `system` | config | Enter system configuration submode |
| `?` | any | Help — lists available commands |
| `exit` | any | Exit current mode / disconnect |
| `interface <name> wireguard asc ...` | if-config | Set AmneziaWG ASC params (4.2+ only) |

### Important: CLI is NOT Linux

KeeneticOS CLI is a **proprietary command interface**, not a bash/Linux shell.
- Linux commands (`which`, `ls`, `cat`, `df`, `uname`, `grep`) do NOT work
- The router runs a custom OS on MIPS architecture
- Use dedicated NDMS command set only

### CLI + RCI Cooperation

- **CLI:** interactive exploration, single-config commands
- **RCI (HTTP API):** automated queries, scripting via curl/Python
- Same authentication (password hash challenge-response)
- Some commands only exist in one or the other

## Autopsy: Keenetic WireGuard — Live Peer Statistics

When querying the full interface list via RCI (`show/interface` with no filter), WireGuard interfaces include real-time peer data embedded in the response:

```json
{
  "wireguard": {
    "public-key": "cg+O1I3AAhV/jpagCzpgpwlxua6eOlN4H5l5eApG3hA=",
    "listen-port": 48951,
    "status": "up",
    "peer": [{
      "public-key": "SqQsxjdGLKHt2+VpVIt2OJCWeUKs1jzTvz1OEVr+aDo=",
      "local": "100.86.249.121",
      "local-port": 48951,
      "via": "FastEthernet0/Vlan2",
      "remote": "46.30.47.120",
      "remote-port": 54711,
      "rxbytes": 27692,
      "txbytes": 102308,
      "last-handshake": 127,
      "online": true
    }]
  }
}
```

**Key fields for speed/activity analysis:**
| Field | Meaning |
|-------|---------|
| `rxbytes` | Bytes received since connection start |
| `txbytes` | Bytes transmitted since connection start |
| `last-handshake` | Seconds since last successful handshake |
| `online` | Peer is currently connected (boolean) |
| `remote` | External endpoint IP of the VPN server |
| `remote-port` | External endpoint port |

**Activity heuristics:**
- **Active tunnel:** `rxbytes`/`txbytes` in GB or hundreds of MB, `last-handshake < 120s`
- **Idle/stale tunnel:** `rxbytes` < 100 KB, `txbytes` < 100 KB (only handshake keepalives)
- **Unstable:** `online: false` or `last-handshake > 300s`
- The lowest `last-handshake` value across peers has the most current connection

The API returns **cumulative byte counts** (not speed in bps). Compute speed by taking two measurements over an interval and calculating the delta.

## AmneziaWG on KeeneticOS 4.2+

KeeneticOS **4.2+** supports the **AmneziaWG protocol natively**. Standard WireGuard built into NDMS 3.x does NOT support AWG parameters (Jc, Jmin, Jmax, S1, S2, H1-H4).

### Requirements
- **Firmware:** KeeneticOS 4.2.1+ (check via `show version` in CLI)
- **Component:** WireGuard VPN must be installed (System > Component options)
- **Model compatibility:** KN-1210 (MIPS, 64MB RAM) should support 4.x — verify on keenetic.com

### Setup Steps for AWG on Keenetic

1. **Update firmware** to 4.2+ via web interface (System > Firmware Update) or download from keenetic.com
2. **Import the AmneziaWG .conf** as a standard WireGuard config (Other Connections > WireGuard > Upload from file)
3. **Enable internet access** through the new connection (check Use for accessing the internet)
4. **Note the interface name** from `show interface` CLI output (e.g., `Wireguard4`)
5. **Set ASC parameters** via CLI:
   ```
   interface Wireguard4 wireguard asc 4 10 50 82 99 1703387805 1485247836 1985551247 1080595976
   ```
   Format: `interface <name> wireguard asc <Jc> <Jmin> <Jmax> <S1> <S2> <H1> <H2> <H3> <H4>`

### ASC Parameter Mapping

```
[Interface] section in .conf:        CLI command parameter:
Jc = 4       (junk packet count)     → 4
Jmin = 10    (min junk size)         → 10
Jmax = 50    (max junk size)         → 50
S1 = 82                              → 82
S2 = 99                              → 99
H1 = 1703387805                      → 1703387805
H2 = 1485247836                      → 1485247836
H3 = 1985551247                      → 1985551247
H4 = 1080595976                      → 1080595976
```

### Reference
- Official Amnezia guide: https://docs.amnezia.org/documentation/instructions/keenetic-os-awg/
- Community guide: https://github.com/arturbikbaev/AmneziaWG-for-KeeneticOS

## Example: Real-World WireGuard Setup on KN-1210

From an actual KN-1210 running NDMS 3.07.C.5.0-0, the following WireGuard configuration was found:

### 3 WG Tunnels + 3 Policies

| Interface | Subnet | Server IP | Policy | Table |
|-----------|--------|-----------|--------|-------|
| Wireguard1 (MyNL) | 10.77.77.0/24 | 46.30.47.120:54711 | Policy1 (VPN NL) | 42 |
| Wireguard2 (MSK) | 10.77.88.4/32 | 95.142.39.32:55933 | Policy2 (VPN RU) | 43 |
| Wireguard3 (GeR) | 10.8.1.3/32 | 45.134.15.185:37487 | Policy4 (VPN GeR) | 44 |

### Common Policy Structure

Each policy routes:
- `0.0.0.0/0` -> respective WG interface (all traffic through VPN)
- `10.1.30.0/24` -> Guest (bypass VPN)
- `10.77.77.0/24` -> Wireguard1 (WG1 subnet)
- `100.86.128.0/17` -> ISP (local ISP, bypass VPN)
- `192.168.1.0/24` -> Home (LAN, bypass VPN)

## Security Audit Checklist

| Check | RCI Query | What to look for |
|-------|-----------|------------------|
| WAN access | `show/rc/ip/http` | `security-level.public: true` = **exposed to internet** |
| HTTPS | `show/rc/ip/http` | `ssl.redirect: true`? If missing → HTTP only |
| Admin password | `show/rc/user` | Check if default hashes are present |
| Lockout policy | `show/rc/ip/http` | `lockout-policy.threshold: 5` — reasonable |
| Firmware age | `show/version` | `release` date. Old = security risk |
| Open ports | `show/rc/ip` | Port 80, 23 (telnet), 21 (FTP) — disable if not needed |
| AdGuard DNS | components list | Check if `adguard-dns` component is active |
| DDNS | `show/ndns` | DDNS hostname — potential attack surface |

## Model-Specific Info

**Keenetic 4G (KN-1210):**
- MIPS architecture
- 64 MB RAM (30 MB free typical)
- Dual-band WiFi (2.4GHz BGN + 5GHz AC)
- 4G LTE modem support (USB)
- Components: OpenVPN, WireGuard, L2TP, PPTP, IGMP, DHCP, AdGuard DNS, UPnP
- 1 FastEthernet WAN port, LAN ports

## Pitfalls & Gotchas

1. **Challenge changes per GET** — the `X-NDM-Challenge` value is unique per request. Always use the challenge and cookie from the SAME GET /auth response.
2. **Cookie name is random** — `VFSKBXMLYAN` is just an example. Extract the actual cookie name from the `Set-Cookie` header each time.
3. **401 is expected on GET /auth** — that's how the challenge is delivered. Don't interpret as auth failure.
4. **Password hash uses lowercase hex** — both MD5 and SHA-256 outputs are lowercase. Uppercase will fail.
5. **WG config NOT visible via RCI show/wireguard** — `show/wireguard` and `show/wg` endpoints return "not found". However, WG peer data IS embedded within the full `show/interface` response under the `wireguard` key. Use telnet `show running-config` for the full config including private keys.
6. **VPN interfaces DO appear in full interface list** — `Wireguard1` WILL appear in the full unfiltered `show/interface` response (at the end, after all physical ports). The earlier advice about them being invisible was wrong — they just appear at the bottom of the large JSON.
7. **RCI `get` vs `show`** — `get` queries config storage and may be unimplemented for many paths. `show` queries runtime state and is more widely available.
8. **Components list shows capabilities** — check `show/version` → `ndw.components` for available features like `wireguard`, `openvpn`, `l2tp`.
9. **Firmware NDMS 3.x vs 4.x** — NDMS 4.x has different features (AmneziaWG support, updated UI). This skill covers NDMS 3.x (3.07.C.5.0-0 tested). Paths and commands may differ on 4.x.
10. **show/interface returns everything** — but physical ports (FastEthernet0/0-3) come FIRST, then WLAN, then Bridge/Vlan, then WireGuard at the end. Parse the full JSON to find all interfaces.
11. **KeeneticOS CLI is NOT bash** — `which`, `ls`, `cat`, `df`, `uname` do not work. Use only NDMS command set.
12. **AmneziaWG requires 4.2+** — on NDMS 3.x, `interface wireguard asc` returns "no such command: asc". Attempting ASC config on old firmware will fail.
13. **`configure terminal` and `enable` do not exist on NDMS 3.x** — these are Cisco-style commands that some newer KeeneticOS versions might support, but not 3.x.
14. **RCI `firmware/upgrade` endpoint returns empty on 3.x** — firmware update checking is only available through the web UI on older firmware.
15. **RCI `set`/`apply`/`configure` DO NOT work for WiFi interfaces on NDMS 3.x** — Trying `{"set": {"interface": {"WifiMaster0": {"channel": 6}}}}` or any variant returns `"not found"`. WiFi channel configuration is only possible via **telnet CLI** on this firmware version. The RCI `cmd` parameter with a plain text string returns an empty `{}` response (silent no-op). Use telnet for WifiMaster0 changes.
16. **`show running-config interface WifiMaster0` doesn't work on NDMS 3.x** — it returns `"argument parse error"`. Instead, run `show running-config` and grep/filter the output, or query via RCI `show/interface` and look at the `WifiMaster0` entry.
18. **Telnet auth timing on 4.x** — KeeneticOS 4.x closes the connection immediately if credentials aren't sent fast enough. Use Python telnetlib with minimal delay between username and password (0.3s) rather than interactive telnet. See "Authentication Timing (CRITICAL on 4.x)" section above.
19. **`show running-config | no-more` fails on 4.x** — returns `Core::Configurator error: incorrect request`. On 4.x, just use `show running-config` without the pipe — the CLI doesn't paginate by default.
20. **Python telnetlib `read_very_eager()` has no `timeout` kwarg** — on Python 3.10, calling `read_very_eager(timeout=3)` raises `TypeError`. Use `time.sleep(N)` before calling `read_very_eager()` instead.
21. **KeeneticOS 4.x telnet banner** — shows `KeeneticOS version 4.03.C.6.2-7` (vs just `KeeneticOS version X.Y.Z` on 3.x). Welcome text includes year range "(c) 2010-2025 Keenetic Ltd."
