# Keenetic-1730 — Live Router Profile

Captured from an actual session via telnet on KeeneticOS 4.03.C.6.2-7.

## System

| Field | Value |
|-------|-------|
| Hostname | Keenetic-1730 |
| Domain | WORKGROUP |
| Firmware | KeeneticOS 4.03.C.6.2-7 |
| CPU load | 7% |
| Memory | 63392/131072 KB (~48% used) |
| Swap | 0/0 (none) |
| Uptime | ~3.6h |
| Conntrack | 184/16384 |

## Interfaces

### Home Bridge (LAN)
- **Name:** Home (Bridge0)
- **IP:** 192.168.3.1/24
- **MAC:** 50:ff:20:a8:5a:b1
- Members: FastEthernet0/Vlan1 (down), WifiMaster0/AccessPoint0 (down), WifiMaster1/AccessPoint0 (up)

### Guest Network (Bridge1)
- **Name:** Guest (Bridge1)
- **Traffic-shape:** `traffic-shape rate 5120` (5 Mbps limit)
- Members: FastEthernet0/Vlan3 (down), WifiMaster0/AccessPoint1 (down), WifiMaster1/AccessPoint1 (down)

### CdcEthernet0 (4G WAN)
- **IP:** 192.168.100.100/24
- **Default GW:** 192.168.100.1
- **WWAN IP:** 7.35.101.207
- **No traffic-shape** (unlimited, capped by signal only)
- **Operator:** Tele2
- **IMEI:** 863645059443074
- **IMSI:** 250204704516191
- **Modem:** ZTE ALK Mobile Boardband (USB, vendor 19d2:0558)
- **Signal:** RSRP -104dBm (level 2/5)
- **Auth:** PASSED

### Wi-Fi 2.4GHz (WifiMaster0)
- **Channel:** 1 (20MHz, bitrate 300Mbps)
- **Radio:** up
- **Temperature:** 60°C
- **AccessPoint:** down (not connected)
- **WifiStation:** probe to "My_IneT_2.4" — fail: probe-timeout

### Wi-Fi 5GHz (WifiMaster1)
- **Channel:** 56 (80MHz, bitrate 867Mbps)
- **Radio:** up
- **Temperature:** 61°C
- **AccessPoint_5G:** up, SSID "Keenetic-1730", WPA2
- **Guest AP (5G):** down
- Additional AP slots 2-6: all down (standard Keenetic layout)

### Ethernet Ports
- FastEthernet0 — switch with 4 ports (0-3), **all down** (no wired clients)
- VLAN1 (Home) — down
- VLAN2 (ISP) — down (4G is primary WAN)
- VLAN3 (Guest) — down

## Routing Table

```
0.0.0.0/0        → 192.168.100.1  CdcEthernet0     U 0
1.0.0.1/32       → 0.0.0.0        Wireguard4       U 0
1.1.1.1/32       → 0.0.0.0        Wireguard0       U 0
172.29.172.254/32→ 0.0.0.0        Wireguard2       U 0
192.168.3.0/24   → 0.0.0.0        Home             U 0
192.168.100.0/24 → 0.0.0.0        CdcEthernet0     U 0
```

## WireGuard Tunnels

| Name | Description | Address | Listen Port | Uptime | Endpoint | Public Key |
|------|-------------|---------|-------------|--------|----------|------------|
| Wireguard0 | MaRUssya 🇷🇺 | 10.77.88.2 | 41738 | ~14 min | 95.142.39.32:55933 | rde6ZPOHVYNTU55dHwqBa/zyNJWwWeYmF/ZX1LX//AI= |
| Wireguard1 | VaNiL 🇳🇱 | 10.77.77.4 | 42919 | **down** | 46.30.47.120:54711 | SWj10UQoBrznpw/rsv4NNsI8u9UBTHR/53SjwX0SiiY= |
| Wireguard2 | SrBro | 10.8.1.8 | 41783 | ~3.6h | 87.121.38.60:30772 | d7WO57hH52qet/ZxRsKjuGUd0fPIhbMuYazH5taptmI= |
| Wireguard3 | ParaFiN 🇫🇮 | 10.8.1.6 | 41823 | ~3.6h | 204.77.1.107:43354 | 1w0fo6ECSsJITl+879JCU2pCao9Mol0SAH6u/NYTXAU= |
| Wireguard4 | GeR 🇩🇪 | 10.8.1.3 | 0 (client) | ~21 min | 45.134.15.185:37487 | ywL9dLPuaFPzDa4Gy6qA7xJYvrFaUaQLUVcTGVWCNDc= |

### AmneziaWG ASC Parameters

Three interfaces use AmneziaWG protocol with ASC obfuscation parameters (9-value format: Jc Jmin Jmax S1 S2 H1 H2 H3 H4):

| Interface | ASC Values | Notes |
|-----------|------------|-------|
| Wireguard0 (RU) | none | Standard WireGuard, no ASC |
| Wireguard1 (NL) | `108 555 777 0 0 1 2 3 4` | Has ASC but **interface is down** |
| Wireguard2 (SrBro) | `3 10 50 116 39 35194790 801430376 1134096395 1805096884` | AWG obfuscation active |
| Wireguard3 (FiN) | `20 10 50 19 34 2051442962 1144257569 1427343434 753271071` | AWG obfuscation active |
| Wireguard4 (GeR) | none | Standard WireGuard, likely full-cone traffic |

### WG Keepalive & PSK

All tunnels use:
- **keepalive-interval:** 25 seconds
- **preshared-key:** set on all except Wireguard0
- **allowed-ips:** `0.0.0.0 0.0.0.0` (full tunnel — all traffic routed through WG)
- **connect:** enabled on all (auto-connect on boot)

### WG Interface Config (from running-config)

```
interface Wireguard0
    description MaRUssya
    security-level public
    ip address 10.77.88.2 255.255.255.255
    ip mtu 1324
    ip global 350
    ip tcp adjust-mss pmtu
    wireguard peer q3lnRFakoZ3ORKcdbqNHSGvVQRd4tuhZr4aN66VVAnI= !RU
        endpoint 95.142.39.32:55933
        keepalive-interval 25
        allow-ips 0.0.0.0 0.0.0.0
        connect
    up
```

## Interface Priorities (ip global)

```
CdcEthernet0  33117  ← primary WAN (defaultgw=yes)
Wireguard0      350  ← RU (MaRUssya)
Wireguard1      175  ← NL (VaNiL — down)
Wireguard2       87  ← SrBro
Wireguard3       43  ← FiN (ParaFiN)
Wireguard4       21  ← GeR (lowest, but full-cone so gets some routes)
```

Higher number = higher priority for default route selection.

## IP Hotspot — Client-to-Policy Bindings

```
ip hotspot
    policy Home permit
    host 8c:16:45:90:44:d4 permit
    host 8c:16:45:90:44:d4 policy Policy3      → ParaFiN (FiN)
    host 8c:16:45:90:44:d4 priority 3
    host f2:5c:08:88:60:e8 permit               → no policy (uses default)
    host d0:c5:d3:aa:35:17 permit
    host d0:c5:d3:aa:35:17 conform
    host 32:9f:5f:5c:de:d2 permit
    host 32:9f:5f:5c:de:d2 policy Policy4      → GeR
    host 32:9f:5f:5c:de:d2 priority 3
    host b0:fc:36:5e:ca:db permit
    host b0:fc:36:5e:ca:db priority 3           → no policy, but priority 3 on default route
```

### IP Policies

| Policy | Description | Interface | Clients |
|--------|-------------|-----------|---------|
| Policy0 | RU | Wireguard0 | — |
| Policy1 | NL | Wireguard1 | (down) |
| Policy2 | SrB | Wireguard2 | — |
| Policy3 | FiN | Wireguard3 | `8c:16:45:90:44:d4` |
| Policy4 | GeR | Wireguard4 | `32:9f:5f:5c:de:d2` |

Each policy permits ONLY its own Wireguard interface and denies all others + CdcEthernet0 + ISP + WifiStation0.

## Telnet Connection Pattern

```python
import telnetlib, time, re

tn = telnetlib.Telnet("192.168.3.1", 23, timeout=15)
time.sleep(2)
tn.read_very_eager()
tn.write(b"admin\n")
time.sleep(0.3)
tn.write(b"VPS_ROOT_PASSWORD_PLACEHOLDER\n")
time.sleep(2)
# Now at (config)> prompt
```

## Useful Commands (confirmed working on 4.03.C.6.2-7)

- `show system` — hostname, uptime, memory, cpu
- `show ip route` — routing table (shows WG routes + default)
- `show interface` — all interfaces with full details
- `show running-config` — full config (do NOT use `| no-more` — fails on 4.x)
- `show ip hotspot` — client-to-policy bindings and MAC assignments
- `interface <name>` → `?` — explore available sub-commands per interface type
