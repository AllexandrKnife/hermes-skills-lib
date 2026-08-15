# VPS Inventory — AdGuardHome + VPN DNS Integration Status

## 45.134.15.185 (Frankfurt, firstbyte.club)
- **SSH**: root по паролю (sshpass, StrictHostKeyChecking=no); ключи не настроены.
  Пароль общий с роутером Keenetic — см. память / скилл wsl-vpn-on-demand. Хост: vm4246275.firstbyte.club.
- **Host OS**: Ubuntu 22.04
- **AdGuardHome**: systemd service, enabled, active
  - Web UI: 0.0.0.0:3000
  - DNS: 0.0.0.0:53
  - Upstream: unbound (127.0.0.1:5353) + Quad9 DoH + Cloudflare DoH + AdGuard DoH (parallel)
  - Cache: 64MB
  - Filter: AdGuard DNS filter (158k rules)
- **DNS optimization**: unbound installed, aggressive caching, parallel mode
- **VPN stack**: sing-box (sb.json server, sbox.json client)
  - 5 protocols: VLESS+Reality, VMess+WS, Hysteria2, TUIC v5, AnyTLS
  - DNS chain: adguard → aliDns → local → proxyDns → fakeip, final: adguard
- **Other**: Hermes Gateway, mita (Mieru), Amnezia WG docker, Hermes Agent
- **iptables**: redirects for wg0, docker networks
- **Status**: ✅ Fully operational + optimized
- **Benchmark note**: unbound cold query ≈ Quad9 DoH (both in Frankfurt anycast footprint). Benefit is hot cache + resilience, not cold speed.

## 46.30.47.120 (Netherlands, eurodir.ru)
- **Host OS**: Debian 6.1
- **AdGuardHome**: systemd service, enabled, active
  - Web UI: 0.0.0.0:3000
  - DNS: 0.0.0.0:53
  - Upstream: unbound (127.0.0.1:5353) + Quad9 DoH + Cloudflare DoH + AdGuard DoH (parallel)
  - Cache: 64MB
  - Filter: AdGuard DNS filter (158k rules)
- **DNS optimization**: unbound installed, aggressive caching, parallel mode
- **VPN stack**: sing-box + native WireGuard + Amnezia (AWG, Xray, Shadowsocks)
  - sing-box sbox.json: adguard → aliDns → local → proxyDns → fakeip, final: adguard
  - Native WireGuard: wg0, port 54711, 11 clients
  - Amnezia: AWG (33940), Xray (777), Shadowsocks (port 45214)
- **amnezia-dns**: removed (stopped + deleted)
- **iptables**: redirects for 172.29.172.0/24, 172.17.0.0/16, wg0, 172.29.172.254
- **resolv.conf**: 127.0.0.1 → 1.1.1.1
- **Status**: ✅ Fully operational + optimized

## 87.121.38.60 (babayka.duckdns.org)
- **Host OS**: Ubuntu 22.04 (minimal)
- **AdGuardHome**: systemd service, enabled, active
  - Web UI: 0.0.0.0:3000
  - DNS: 0.0.0.0:53
  - Upstream: unbound (127.0.0.1:5353) + Quad9 DoH + Cloudflare DoH + AdGuard DoH (parallel)
  - Cache: 64MB
  - Filter: AdGuard DNS filter (158k rules)
- **DNS optimization**: unbound installed, aggressive caching, parallel mode
  - install: removed broken lazygit-team PPA (no Release file for jammy) before apt
- **VPN stack**: sing-box + Amnezia
  - sing-box sbox.json: adguard → aliDns → local → proxyDns → fakeip, final: adguard
  - Amnezia: AWG (30772), WireGuard (36614), Xray (443)
- **amnezia-dns**: removed
- **systemd-resolved**: stub disabled (DNSStubListener=no)
- **iptables**: redirects for 172.29.172.0/24, 172.17.0.0/16, 172.29.172.254
- **resolv.conf**: 127.0.0.1 → 1.1.1.1
- **Status**: ✅ Fully operational + optimized
- **Note**: dig/host/nslookup not installed — use Python socket for DNS testing
