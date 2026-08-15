# KeeneticOS 5.0.8 + WireGuard client — worked diagnosis case (2026-08)

## Setup

- Router: Keenetic Extra KN-1713 @192.168.1.1, KeeneticOS 5.0.8 (release 5.00.C.8.0-1, mips), telnet:23, web :80.
- Task: new full-tunnel WG client (Wireguard5 "gEr") to VPS 5.39.255.242:51871 (UDP), subnet 10.7.0.0/24.
- Symptom: connection "enabled" on the router, fresh handshake, but traffic never reached the VPS — only keepalives.

## Server-side facts (Ubuntu 22.04 VPS)

- `wg show`: fresh handshake; transfer ~12 KiB rx / 17 KiB tx — keepalive scale.
- 20 s `tcpdump -i wg0`: 0 packets — the router sends only WG keepalives (~1 pkt / 25 s).
- `iptables -L FORWARD -v -x`: 54 pkts wg0→ens18 / 125 pkts ens18→wg0 cumulatively — a little traffic had flowed once (user's early test), then silence.
- `sysctl net.ipv4.conf.*.rp_filter` = 2 (loose) everywhere — not a factor.
- conntrack entries for 10.7.0.2: 0 (they expire; absence ≠ no traffic ever).
- Pitfall hit: `wg-quick up` → `ip: command not found`. Root cause: `apt autoremove -y --purge` during package cleanup had removed iproute2 on this minimal image. Fix: `apt-get install -y iproute2`. Verify `/usr/sbin/ip` afterwards; the earlier session's `ip`-using commands had run before the cleanup.

## Router-side discovery

CLI (keen_telnet_cli.py):
- `show ip` → empty on 5.0.8 (skill notes for 4.3.8 show JSON wans/wbk — stale on 5.x).
- `show running-config` → works, full dump. Key excerpts:
  - `interface Wireguard5`: `ip address 10.7.0.2 255.255.255.0`, `ip mtu 1420`, `ip global 16033`, `ip tcp adjust-mss pmtu`, peer `rOoVb/...` with `endpoint 5.39.255.242:51871`, `keepalive-interval 25`, `allow-ips 0.0.0.0 0.0.0.0`, `connect`.
  - `ip global` priorities: WG5=16033 (lowest → highest priority), WG0=32067, WG1=64226, WG2=65520, WG3=65521, WG4=64135, PPPoE0=65522.
  - `ip policy Policy1 "VPN GeR"`: `permit global Wireguard5` + `permit global Wireguard0`; everything else `no permit`.
  - `ip hotspot host <mac> policy Policy1` binds: 32:c4:66:c7:84:41 (INFINIX HOT 50 PRO), 48:5c:2c:f8:77:50 (Android TV KiCKPI), 70:66:2a:01:e0:5f (PlayStation), 06:c2:55:e6:f6:c8 (Xiaomi 11 Lite).
  - `ip name-server 1.1.1.1 "" on Wireguard5` — the imported config's `DNS = 45.134.15.185` did NOT survive as-is; DNS per interface must be verified in running-config.

RCI (auth per keen_api_auth.py, cookie jar kept across calls):
- `GET /rci/show/interface/Wireguard5` — runtime: peer public-key, remote-port, via PPPoE0, rxbytes/txbytes, last-handshake, online:true, `defaultgw:false`.
- `GET /rci/show/ip/hotspot` — live clients; cross-referenced policy bindings and `active` flags.
- `GET /rci/show/ip/route` — THE decisive output:
  `0.0.0.0/0 → PPPoE0` metric 1000 (default route NOT on WG5), plus per-tunnel subnet routes (10.7.0.0/24 → Wireguard5).
- 404/empty on 5.0.8: `/rci/show/route`, `/rci/show/dhcp`, `/rci/show/ipv4`, `/rci/show/ipv6`, `/rci/show/dns`, `/rci/export/configuration`, `/rci/show/ip` (returns `{}`).
- `POST /rci/interface/Wireguard5 {"defaultgw": true}` → HTTP 200 `{}` but `defaultgw` stayed false. Not a settable flag.

SPA bundle (`/main-*.js`) contains `show.ip.route`, `show.ip.hotspot`, `show.ip.conntrack`, `show.device-list` service names — useful for endpoint discovery. `allowed-ips` strings in the bundle were all WireGuard-server UI, not client.

## Root cause

Default route remained on PPPoE0; the WG policy (Policy1) bound only 4 devices, and the user's test device was not among them. The tunnel itself was healthy (handshake, `allow-ips 0.0.0.0 0.0.0.0`, lowest `ip global` priority). Fix = bind the test device to the policy (or raise WG to router-wide default) — server-side NAT was fine and needed no changes.

> LATER CORRECTION (continuation in `keeneticos5-wireguard-diagnostics.md`): the user's test device
> (Xiaomi 11) WAS bound to Policy1 all along. The actual killer was DNS: the WG connection used
> `ip name-server 1.1.1.1`, the router resolves via its own PPPoE direct route, and 1.1.1.1 is
> TSPU-blocked → DNS dead → "no internet through WG". A VLESS proxy from the same phone worked
> (remote DNS). After switching the connection DNS to 45.134.15.185, traffic flowed — then an
> MTU/MSS stall remained. Read the stage-2 file for the fix syntax and stall signature.

## Gotchas

- Keenetic does not answer ICMP on its tunnel IP by default → ping loss to 10.7.0.2 is expected, not a fault.
- `defaultgw: no` on ALL WG interfaces in `show interface` is normal on 5.0.8 — route table (`/rci/show/ip/route`) is the ground truth.
- User interrupts long interactive probes («стоп») — keep checks short and targeted (short tcpdump windows, one command per call).
