---
name: amnezia-vpn
description: Deploy, manage, and troubleshoot Amnezia VPN servers — container architecture, user management, error code diagnosis, and SSH/API management patterns.
category: devops
---

# Amnezia VPN — Server Management

Manage an Amnezia VPN server running as Docker containers. Covers the standard 4-container architecture, user creation via host CLI (workaround when the phone app's SSH management fails), and error code diagnosis.

## Triggers

- User mentions "Amnezia", "AmneziaVPN", "Амнезия", "амнезия впн", or "AWG"/"AmneziaWG"
- User reports "error 302" / "302 ssh" / "SSH error" when trying to manage users from the Amnezia phone app
- Container inspection shows `amnezia-wireguard`, `amnezia-awg`, `amnezia-xray`, `amnezia-dns` containers
- User needs to add/remove users without using the phone app
- User needs help choosing between standard WireGuard and AmneziaWG based on ISP DPI profile
- Pre-deployment: user asks which Amnezia protocol to use — test DPI first with the `dpi-analysis` skill

### DPI-aware protocol selection

Before deciding which Amnezia containers to deploy, check the ISP's DPI profile:

| DPI type | Recommended Amnezia protocol | Why |
|----------|------------------------------|-----|
| SNI-based TLS drop (YouTube, Discord blocked) | **AmneziaWG** + Xray VLESS+REALITY | AWG obfuscation (Jc/Jmin/Jmax) hides WireGuard signatures; REALITY imitates TLS to a whitelisted site |
| IP-based SYN drop (Instagram blocked) | **Standard WireGuard** | UDP on non-standard port > 30000 is never blocked by IP alone |
| Active probing / China-level DPI | **AmneziaWG only** | Xray with TLS may be detected; AWG's fake TCP mode + random padding evades probes |
| Light DPI (no blocks but DNS poisoned) | **Xray VLESS+XTLS** | Fastest option, no obfuscation overhead |

Use the `dpi-analysis` skill (`skill_view(name='dpi-analysis')`) for a full ISP characterisation before deployment.

## Container Architecture

Standard AmneziaVPN deployment runs 4 containers on a dedicated Docker bridge network:

| Container | Image | Port | Subnet Role |
|---|---|---|---|
| `amnezia-wireguard` | `amnezia-wireguard` | 36614/udp | Standard WireGuard, stores `clientsTable` (JSON user DB) |
| `amnezia-awg` | `amnezia-awg` | 30772/udp | AmneziaWG (WireGuard fork with Jc/Jmin/Jmax/S1/S2/H1-H4 obfuscation) |
| `amnezia-xray` | `amnezia-xray` | 443/tcp | Xray-core with VLESS+REALITY or VLESS+XTLS |
| `amnezia-dns` | `amnezia-dns` | 53/tcp,53/udp | DNS server (usually AdGuard Home or stubby) |

All containers connect to a **custom bridge network** (typically `amnezia-dns-net` or `amn0`, subnet e.g. `172.29.172.0/24`).

The host uses an internal bridge interface (`amn0`) with Docker NAT forwarding via DNAT rules.

### Per-container internals

**amnezia-wireguard**:
- Config: `/opt/amnezia/wireguard/wg0.conf`
- User DB: `/opt/amnezia/wireguard/clientsTable` — JSON array with `clientId` (base64 public key), `userData.clientName`, `userData.creationDate`
- Entrypoint: `dumb-init /opt/amnezia/start.sh`
- No SSH server inside — minimal container

**amnezia-awg**:
- Config: `/opt/amnezia/awg/wg0.conf`
- AmneziaWG parameters: `Jc`, `Jmin`, `Jmax`, `S1`, `S2`, `H1-H4`
- Uses same PSK per-container (shared preshared key across all peers)

**amnezia-xray**:
- Config: `/opt/amnezia/xray/server.json`
- VLESS+REALITY (TLS via `www.googletagmanager.com` impersonation) or VLESS+XTLS
- Uses `realitySettings` with `dest`, `privateKey`, `serverNames`, `shortIds`

## Error Codes (Phone App Management)

The Amnezia phone app manages users by connecting to the server via the VPN tunnel and then running SSH commands. Specific error codes:

| Code | Meaning | Root Cause |
|---|---|---|
| **301** | SSH auth failed | Wrong SSH password/user |
| **302** | SSH connection failed | Can't reach SSH endpoint — container has no SSH, port blocked, or routing issue through VPN tunnel |
| 303+ | Container command failed | App connected but management script returned error |

### Error 302 — Root Cause Analysis

The most common cause: **the container does not run an SSH server**. The phone app tries to SSH into the container (via its Docker IP or the host IP) to add peers, but no SSH process is listening.

Secondary causes:
- **Routing loop** — phone is connected via VPN tunnel and tries to SSH to the host's public IP; traffic goes into the tunnel, arrives at the server via wg0, and routing confuses the response path
- **`send_redirects = 1`** — host sends ICMP redirects that confuse SSH connections arriving via the tunnel
- **Port 22 NOT exposed on the container**

## User Management (Workaround via Host CLI)

When the phone app fails with error 302, users can be managed manually through the host:

### Add a new WireGuard peer

```bash
# 1. Generate keys
PEER_NAME="UserName [Device]"
PEER_IP="10.8.1.<next_id>/32"

PRIVATE_KEY=$(wg genkey)
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)
PSK=$(docker exec amnezia-wireguard cat /opt/amnezia/wireguard/wireguard_psk.key)

# Or reuse existing PSK
PSK=$(head -1 /opt/amnezia/wireguard/wireguard_psk.key)

# 2. Read existing config
docker exec amnezia-wireguard cat /opt/amnezia/wireguard/wg0.conf

# 3. Add peer to wg0.conf (compute next IP from existing peers)
# Append to the [Peer] section:
cat << EOF >> /tmp/new_peer.conf
[Peer]
PublicKey = $PUBLIC_KEY
PresharedKey = $PSK
AllowedIPs = $PEER_IP
EOF

# 4. Copy config into container
docker cp /tmp/new_peer.conf amnezia-wireguard:/opt/amnezia/wireguard/
# Then append it (it's safer to read → edit → write the whole file)

# 5. Update clientsTable inside container
docker exec amnezia-wireguard sh -c "cat /opt/amnezia/wireguard/clientsTable"
```

The better approach — read the file, edit locally, write back:

```bash
# Read config, add peer, write back
docker exec amnezia-wireguard cat /opt/amnezia/wireguard/wg0.conf > /tmp/wg0.conf
# edit /tmp/wg0.conf — add [Peer] section
docker cp /tmp/wg0.conf amnezia-wireguard:/opt/amnezia/wireguard/wg0.conf
```

### Apply new peer to running interface

```bash
docker exec amnezia-wireguard wg set /opt/amnezia/wireguard/wg0.conf peer $PUBLIC_KEY \\
  preshared-key /opt/amnezia/wireguard/wireguard_psk.key \\
  allowed-ips $PEER_IP
```

Or simply restart the container (restart policy is usually `always`):

```bash
docker restart amnezia-wireguard
```

### Determine next available IP

```bash
docker exec amnezia-wireguard grep 'AllowedIPs' /opt/amnezia/wireguard/wg0.conf | \\
  sed 's/.*= //' | sort -t. -k4 -n | tail -1
```

### Generate Xray UUID for a new client

```bash
uuidgen
# Then add to /opt/amnezia/xray/server.json under "inbounds[0].settings.clients"
```

## Diagnostics Quickstart

```bash
# Check all containers status
docker ps -a --filter "name=amnezia"

# Check container network on amn0 bridge
docker network inspect amn0 2>/dev/null || docker network inspect amnezia-dns-net 2>/dev/null

# Check host DNAT rules
iptables -t nat -L DOCKER -n --line-numbers

# Check SSH on host
systemctl status ssh
ss -tlnp | grep :22

# Read clients table
docker exec amnezia-wireguard cat /opt/amnezia/wireguard/clientsTable 2>/dev/null

# Read Xray users
docker exec amnezia-xray cat /opt/amnezia/xray/server.json 2>/dev/null | jq '.inbounds[0].settings.clients'

# Count peers in AWG
docker exec amnezia-awg grep -c '\[Peer\]' /opt/amnezia/awg/wg0.conf 2>/dev/null

# Check if host has send_redirects on
sysctl net.ipv4.conf.all.send_redirects
```

## Pitfalls

- **No SSH in containers** — the `amnezia-*` containers are minimal and do not run sshd. The phone app's user management depends on either SSH into the host or a dedicated management API container. If the app fails with error 302, either install SSH in the container (not persistent) or manage users via host `docker exec`.
- **clientsTable != actual peers** — `clientsTable` is a metadata file. The actual WireGuard peers are in `wg0.conf`. They must be kept in sync. Adding a peer to `wg0.conf` without updating `clientsTable` will work for connectivity but the app won't see the user.
- **Shared PSK** — Amnezia containers often use the same PresharedKey from `wireguard_psk.key` for all peers. Don't generate per-peer PSKs unless the config shows them.
- **Hairpin routing** — when connected via VPN, the phone's traffic to the host public IP enters the WireGuard tunnel and the host may not route the SSH response back correctly. Adding a DNAT rule or fixing `send_redirects=0` can help, but the cleanest fix is to manage users via host CLI.
- **Container restarts preserve wg0.conf** — the configs are NOT on Docker volumes (bind mount only for `/lib/modules`). Changes made via `docker exec` + `docker cp` need to be committed to an image or backed up externally, or they're lost on container recreation. Use a script on the host that reads/edits configs through `docker cp`.
- **AWG has different config format** — AmneziaWG adds extra params (`Jc`, `Jmin`, `Jmax`, `S1`, `S2`, `H1-H4`). Don't confuse with standard WireGuard config when editing. The AWG container's config is separate from the standard WireGuard container's config.
- **Backup before editing** — `docker cp` the configs out before editing.

## Reference Files

- [Container Inspection Commands](references/container-inspection-commands.md) — copy-paste-ready commands for inspecting all 4 containers, extracting configs, and adding users manually.
