# KN-1211 session diagnostics (2026-08-02)

Observed on Keenetic 4G (KN-1211), KeeneticOS 4.3.8 (4.03.C.8.0-0), stable, arch mips, region EA.
Telnet (port 23) enabled; SSH (22) closed; web 80/443 open. hw features: wifi_button, single_usb_port,
dual_image, wifi_ft, wpa3. Components include wireguard, pppoe, trafficcontrol, skydns, ndns, openvpn.

## Model facts (why speed caps exist)

- All LAN/WAN ports are FastEthernet: `speed: 100, duplex: full` on FastEthernet0/0 (role ISP/inet).
  Hard cap 100 Mbps — faster tariff is unreachable through this router.
- Single 2.4 GHz radio (WifiMaster0), 802.11n, `bitrate: 300000000` (300 Mbps theoretical, ~60-90 real).
  No 5 GHz band on this model.
- Radio temperature ~64-66 C — warm but not the bottleneck.
- Active WireGuard tunnels (Wireguard0 "SrBro", Wireguard1 "GeR") — on mips, WG crypto degrades
  throughput if traffic routes through them.

## Session findings

- WAN: PPPoE0, up, public 100.67.2.207 via FastEthernet0/Vlan2 (10.197.72.51). WG tunnel IPs 10.8.1.x.
- WiFi: SSID Keenetic-FAU, WPA2, channel 1 -> changed to 11 (user request), bandwidth 40 MHz kept.
- busy-channels on ch1: 1-7 all busy (congested band). After switch to ch11: busy 5-13 — 2.4 GHz
  saturation everywhere; channel change is marginal, hardware (5 GHz / wired) is the real fix.
- DNS: ndnproxy policies on 1.1.1.1, request counts tiny (5-28) — not a bottleneck.

## CLI command reality (KeeneticOS 4.3.8)

Work: `show version`, `show interface`, `show wan`, `show ip` (JSON with wans/wbk),
`show dns` (proxy stats), `interface <name>` + `list`, `channel <n>`, `system configuration save`.
Absent: `show wifi`, `show cpu`, `show memory`, `show system`, `show hosts`, `show arp`,
`show route`, `show log`, `show trafficcontrol`, `show qos`, `scan`, `station`, `help` (no output).

WiFi channel change confirmation line:
`Network::Interface::Mtk::WifiMaster: "WifiMaster0": channel set to 11.`

## Web API notes

- `GET /auth` 401 carries `WWW-Authenticate: x-ndw2-interactive realm="Keenetic 4G" challenge=...`
  and Set-Cookie session (Max-Age=300). Keep the cookie jar.
- Password encryption: SHA256(challenge + MD5("login:realm:password")).hexdigest(), POSTed as JSON
  `{"login":..., "password": enc}`. Plaintext or lost session -> 400 X-Detail 0x2021.
- WiFi air-scan ("wifi-analyzer" in SPA) exists in the web UI but its RCI call was NOT confirmed
  before session was interrupted — dig the bundle (`main.*.js`, grep `getEncryptedPassword` /
  `rci.execute`) before promising scan results.
