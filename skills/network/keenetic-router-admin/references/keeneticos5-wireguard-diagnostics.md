# KeeneticOS 5.0.8 WireGuard diagnostics — KN-1713 session walkthrough

Scenario: WG client on Keenetic Extra (KN-1713, OS 5.0.8, "Wireguard5" gEr, 10.7.0.2) →
VPS server (10.7.0.0/24, UDP 51871). Symptom: tunnel shows "connected" but client
traffic doesn't reach the internet through the VPS.

## Evidence-gathering order (what actually worked)

1. **Server side (VPS)**:
   - `wg show` — handshake age, transfer counters, peer AllowedIPs
   - `/proc/net/dev | grep wg0` — packet/byte counters (compare over time to see real traffic)
   - `iptables -L FORWARD -v -x | grep wg0` — is forwarding actually happening
   - `sysctl net.ipv4.conf.all.rp_filter` — must be loose (2), strict (1) breaks WG forwarding
   - `timeout 30 tcpdump -i wg0 -n -c 50` — what the client actually sends (needs `apt-get install tcpdump`)
2. **Router CLI** (telnet, keen_telnet_cli.py):
   - `show interface` — find `WireguardN` blocks: address, mtu, `defaultgw`, public-key
   - `show running-config` — ground truth: peer block, `ip global`, `ip policy`, name-servers
3. **Router RCI** (keen_api_auth.py flow):
   - `/rci/show/interface/Wireguard5` — runtime: peer online, last-handshake, rx/tx bytes
   - `/rci/show/ip/route` — main routing table
   - `/rci/show/ip/hotspot` — live clients (mac/ip/hostname/priority/active) to map test device → policy
4. **Cross-reference**: which policy binds the test device? `ip policy PolicyN` + `host <mac> policy PolicyN` in running-config.

## Findings that mattered

- Main route table showed `0.0.0.0/0 → PPPoE0` while the tunnel was correctly in use by
  policy-bound clients — policy routing is fwmark-based, invisible in the main table.
- `ip global` priorities: WG5=16033 < WG0=32067 < PPPoE0=65522 → WG5 was the preferred
  global. Client-side `allow-ips 0.0.0.0 0.0.0.0` was already correct.
- **Root cause (stage 1)**: imported WG file's `DNS = 45.134.15.185` did NOT stick; router
  used `ip name-server 1.1.1.1 on Wireguard5`. The router resolves DNS via its OWN default
  route (PPPoE direct), and 1.1.1.1 is TSPU-blocked → DNS dead → "no internet through WG".
  VLESS from the same phone worked because the proxy resolves remotely. Fix:
  `interface Wireguard5` → `no ip name-server 1.1.1.1 "" on Wireguard5` →
  `ip name-server 45.134.15.185 "" on Wireguard5` → `exit` → `system configuration save`
  (full `"" on <iface>` syntax mandatory; short form silently no-ops).
- **Stage 2 (after DNS fix)**: tcpdump on server wg0 showed Google 443 segments reaching
  the client and FORWARD counters growing (54→90 / 125→206) — tunnel now carries real
  traffic. BUT the same 986-byte segment retransmitted 19 s apart with no ACK progress:
  connection stall. Suspected MTU/MSS — `ip tcp adjust-mss pmtu` depends on ICMP PMTU
  messages that home ISPs/TSPU filter. Candidate fix (NOT yet verified in session):
  explicit `ip tcp adjust-mss 1360` + tunnel MTU 1400.

## Commands absent on 5.0.8

`show ip` (empty output), `show route`, `show configuration`, `list` in interface context.
Use `show running-config` + RCI instead.

## SPA endpoint discovery

```
curl -s http://<router>/ | grep -oE 'src="[^"]*\.js"'
curl -s http://<router>/main-XXXX.js -o /tmp/main.js
grep -o 'show\.ip\.[a-z-]*' /tmp/main.js | sort -u   # → show.ip.hotspot, show.ip.route, ...
```
RCI path = dots → slashes under `/rci/` (e.g. `show.ip.hotspot` → `/rci/show/ip/hotspot`).
