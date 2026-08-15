# Amnezia Container Inspection Commands

A centralized reference of the commands used to inspect a running Amnezia VPN deployment.

## Quick Health Check

```bash
docker ps -a --filter "name=amnezia" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Expected output for healthy 4-container deployment:

| Names | Status | Ports |
|---|---|---|
| amnezia-wireguard | Up N hours | 36614/udp |
| amnezia-awg | Up N hours | 30772/udp |
| amnezia-xray | Up N hours | 443/tcp |
| amnezia-dns | Up N hours (healthy) | 53/tcp, 53/udp |

## Network Architecture

```bash
# Host interfaces
ip addr show

# Docker network (amn0 or amnezia-dns-net)
docker network ls
docker network inspect amn0 2>/dev/null || docker network inspect amnezia-dns-net

# DNAT rules (how host maps ports to containers)
iptables -t nat -L DOCKER -n --line-numbers
```

### Typical IP assignment

| Container | Internal IP | Subnet |
|---|---|---|
| amnezia-wireguard | 172.29.172.3 | 172.29.172.0/24 |
| amnezia-awg | 172.29.172.2 | 172.29.172.0/24 |
| amnezia-xray | 172.29.172.4 | 172.29.172.0/24 |

## WireGuard Container Deep Dive

```bash
# Read WG config
docker exec amnezia-wireguard cat /opt/amnezia/wireguard/wg0.conf

# Read user metadata
docker exec amnezia-wireguard cat /opt/amnezia/wireguard/clientsTable | python3 -m json.tool

# Read PSK
docker exec amnezia-wireguard cat /opt/amnezia/wireguard/wireguard_psk.key

# Read keys
docker exec amnezia-wireguard cat /opt/amnezia/wireguard/wireguard_server_private_key.key
docker exec amnezia-wireguard cat /opt/amnezia/wireguard/wireguard_server_public_key.key

# Container entrypoint
docker exec amnezia-wireguard cat /opt/amnezia/start.sh

# No SSH inside
docker exec amnezia-wireguard which sshd  # empty = no SSH
```

## AWG Container

```bash
# AWG config has extra params (Jc, Jmin, Jmax, S1, S2, H1-H4)
docker exec amnezia-awg cat /opt/amnezia/awg/wg0.conf

# Count peers
docker exec amnezia-awg grep -c '\[Peer\]' /opt/amnezia/awg/wg0.conf
```

## Xray Container

```bash
# Full Xray config (VLESS+REALITY)
docker exec amnezia-xray cat /opt/amnezia/xray/server.json | python3 -m json.tool

# List only clients
docker exec amnezia-xray python3 -c "import json; c=json.load(open('/opt/amnezia/xray/server.json')); [print(f'{i[\"id\"]}') for i in c['inbounds'][0]['settings']['clients']]"

# Count clients
docker exec amnezia-xray python3 -c "import json; c=json.load(open('/opt/amnezia/xray/server.json')); print(len(c['inbounds'][0]['settings']['clients']))"
```

## Host SSH Diagnostics

```bash
# SSH server status
systemctl status ssh
ss -tlnp | grep :22

# Fail2ban (if configured)
iptables -L f2b-sshd -n --line-numbers 2>/dev/null

# send_redirects (can cause SSH issues through VPN tunnel)
sysctl net.ipv4.conf.all.send_redirects

# IP forwarding
sysctl net.ipv4.ip_forward
```

## Routing Diagnostics

```bash
# Host routing table
ip route

# NAT/POSTROUTING rules
iptables -t nat -L POSTROUTING -n --line-numbers

# Container routing info
docker inspect amnezia-wireguard --format "{{json .NetworkSettings.Networks}}"
```

## User Management (Workaround)

```bash
# 1. Extract config from container
docker exec amnezia-wireguard cat /opt/amnezia/wireguard/wg0.conf > /tmp/wg0.conf

# 2. Find next available IP
LAST_IP=$(grep 'AllowedIPs' /tmp/wg0.conf | sed 's/.*= //' | sort -t. -k4 -n | tail -1)
echo "$LAST_IP"  # e.g. 10.8.1.2/32
NEXT=$(echo "$LAST_IP" | awk -F. '{print $1"."$2"."$3"."($4+1)}' | cut -d/ -f1)
echo "$NEXT/32"  # e.g. 10.8.1.3/32

# 3. Generate keys
PEER_NAME="UserName"
PEER_IP="$NEXT/32"
PRIVATE_KEY=$(wg genkey)
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)
PSK=$(docker exec amnezia-wireguard cat /opt/amnezia/wireguard/wireguard_psk.key)

# 4. Append peer to config
cat >> /tmp/wg0.conf << EOF

[Peer]
PublicKey = $PUBLIC_KEY
PresharedKey = $PSK
AllowedIPs = $PEER_IP
EOF

# 5. Put config back
docker cp /tmp/wg0.conf amnezia-wireguard:/opt/amnezia/wireguard/wg0.conf

# 6. Update clientsTable
docker exec amnezia-wireguard sh -c "
python3 -c \"
import json
with open('/opt/amnezia/wireguard/clientsTable') as f:
    table = json.load(f)
table.append({
    'clientId': '$PUBLIC_KEY',
    'userData': {
        'clientName': '$PEER_NAME',
        'creationDate': '$(date)'
    }
})
with open('/opt/amnezia/wireguard/clientsTable', 'w') as f:
    json.dump(table, f, indent=4)
\""

# 7. Apply to running interface
docker exec amnezia-wireguard wg addconf wg0 <(cat /opt/amnezia/wireguard/wg0.conf)

# 8. Or restart container
docker restart amnezia-wireguard
```
