---
name: amneziawg-vpn
version: 1.0.0
description: Use when WireGuard is DPI-blocked or deploying AmneziaWG.
critic_status: done
---

# AmneziaWG (AWG) VPN — server deploy & Keenetic client

## When to use

- WG tunnel UP (fresh handshake, keepalives flow) but traffic stalls: same
  segment retransmitted with no ACK progress, FORWARD counters grow, and an
  MSS/MTU clamp didn't help → DPI (TSPU in RU) is killing WG. Symptom that
  separates DPI from MTU: even SMALL segments (≈1 KB) get retransmitted.
- Migrating a WG tunnel to AmneziaWG on a VPS whose client is a Keenetic
  router (KeeneticOS 4.3.4+).

## Protocol version matrix (CRITICAL)

- Keenetic official firmware supports AmneziaWG **v1.0 only**: 4.2 = base
  support (extra CLI steps), 4.3.4+ = full — the router reads ALL junk params
  from the imported config file, no UI fields. v1.5/v2.0 need KeeneticOS
  5.1 Alpha 3+.
- Server MUST speak v1.0 wire protocol. AWG 2.0/3.0 servers are
  wire-incompatible with Keenetic clients. Match versions.

## v1.0 config keys (MUST match server & client — same values both ends)

```
[Interface]
Jc = 5          # junk packet count
Jmin = 30       # junk min size
Jmax = 50       # junk max size
S1 = 16         # init packet junk size
S2 = 16         # response packet junk size
H1 = 1234567890 # init magic header
H2 = 987654321  # response magic header
H3 = 555555555  # underload magic header
H4 = 111111111  # transport magic header
```
(Any u32 values work as long as both ends agree. CRITICAL: H1-H4 are parsed
with kstrtouint — MUST be ≤ 4294967295 (values like 9876543210 are rejected
with -EINVAL). Jc/Jmin/Jmax/S1/S2 are u16; H1-H4 are NUL_STRING in the netlink
API but decimal u32 in the config. A "min-max" range is also accepted — kernel
picks a random u32 in the range per packet, making the 4-byte header look
random to DPI. Verified working set: H1=1234567890 H2=987654321 H3=555555555
H4=111111111.)

## Server deploy (Linux VPS, Ubuntu 22.04 / kernel 5.15 tested)

1. Module source: `amnezia-vpn/amneziawg-linux-kernel-module`, tag `v1.0.*`
   (v1.0 line still maintained 2026 in parallel with v3.0). Old repo name
   `amnezia-vpn/amneziawg` returns 404 — renamed, use the long name.
2. Build from `src/` against kernel headers: `make && make install` (build
   essentials + `linux-headers-$(uname -r)` required). Ubuntu 22.04/5.15
   needs the timer_delete compat patch — see
   references/amneziawg-v1-ubuntu2204.md.
3. Tools: standard `wg-quick` does NOT work — link kind is "amneziawg", not
   "wireguard". Use `awg`/`awg-quick` from `amnezia-vpn/amneziawg-tools`
   releases (prebuilt `ubuntu-22.04-amneziawg-tools.zip`, tag v1.0.*).
4. Blacklist the standard wireguard module first (Ubuntu 22.04 cloud kernels
   ship wireguard.ko as a MODULE, not builtin — check
   `grep wireguard /lib/modules/$(uname -r)/modules.builtin` returns 0):
   `rmmod wireguard` + `/etc/modprobe.d/blacklist-wireguard.conf`.
5. Reuse the existing WG config: same subnet/port/keys (Curve25519 keys are
   compatible), add the junk keys. NOTE: `awg-quick` reads configs from
   `/etc/amnezia/amneziawg/<iface>.conf` — NOT /etc/wireguard/ (it errors
   "`...` does not exist" otherwise). Copy it there and bring up with
   `awg-quick up <iface>`. Existing iptables FORWARD + MASQUERADE rules keep
   working (adjust interface name in them if you renamed it).
6. systemd: the tools zip ships NO unit — create
   `/lib/systemd/system/awg-quick@.service` (copy the wg-quick@.service
   template; ExecStart=/usr/local/bin/awg-quick up %i,
   ExecStop=/usr/local/bin/awg-quick down %i), then
   `systemctl enable --now awg-quick@<iface>`. If you brought the iface up
   manually first, `awg-quick down <iface>` before `systemctl start`.

## Keenetic client

- Import the client config (original AmneziaWG format: [Interface] with
  Address/DNS/PrivateKey + junk keys; [Peer] with server pubkey,
  PresharedKey, Endpoint, AllowedIPs 0.0.0.0/0) via
  "Other Connections → WireGuard → Import from a file". Creates a NEW
  WireGuard-type interface carrying the AWG params.
- Then (import does NOT set these): give the interface a global priority —
  `interface Wireguard<new>` → `ip global <priority>` (observed on KeeneticOS
  5.0.8: LOWER value = more preferred — a tunnel at 16033 carried the
  device's traffic while the old GeR at 32067 was still in the same policy;
  without ANY priority the policy errors
  "no such global interface"), add it
  to the policy (`ip policy PolicyN` → `permit global Wireguard<new>`), bring
  it `up`, remove the old WG interface (`no interface Wireguard<old>` — do
  this AFTER the new interface owns the subnet, else the enable fails with
  "network conflicts with interface"), set DNS
  (`ip name-server <RU-reachable> "" on Wireguard<new>` — full syntax, see
  keenetic-router-admin), `system configuration save`.
- Headless import: the web UI "Import from a file" opens a NATIVE file picker
  (no DOM file input appears) — use the RCI endpoint instead:
  POST /rci/interface/wireguard/import with
  `{"import": <base64 of conf>, "name": "", "filename": "x.conf"}` →
  creates a new interface (e.g. Wireguard6); junk params land in
  running-config as `wireguard asc <Jc> <Jmin> <Jmax> <S1> <S2> <H1> <H2> <H3> <H4>`.
  Full RCI details in keenetic-router-admin references.

## Speed tuning & bottleneck isolation

VPS-side sysctl — /etc/sysctl.d/99-tunnel-tune.conf (важно при RTT до клиентов ~60-80 мс):
```
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```
- BBR: если нет в `tcp_available_congestion_control` — `modprobe tcp_bbr`.
- `default_qdisc=fq` не применяется к уже живущему интерфейсу (останется fq_codel): для 1-2 CPU ок на лету `tc qdisc replace dev <if> root fq`; на ребуте подхватится сам.
- Роутер: MTU 1420 + `ip tcp adjust-mss pmtu` на интерфейсе — оптимально для PPPoE (макс 1432), менять не нужно.

Изоляция узкого места (порядок замеров, каждый отсекает сегмент):
1. Прямой speedtest БЕЗ туннеля → потолок ISP (кейс: 90 Мбит/с — ISP и WiFi ни при чём).
2. Альтернативный туннель (другой сервер/протокол) → отсекает сервер (кейс: обычный WG 21.45 vs AWG 15.52 — обе в одной полосе).
3. Raw-скорость VPS: `curl -o /dev/null -w '%{speed_download}' https://cachefly.cachefly.net/100mb.test` (545 Мбит/с). Cloudflare speed-эндпоинт `speed.cloudflare.com/__down` с VPS часто не отвечает — не показатель.
4. UDP-путь дом→VPS в обход туннеля: `iperf3 -s` на VPS, `iperf3 -u -b 100M` с домашнего клиента → 54-100 Мбит/с без потерь = UDP-шейпинга (TSPU/ISP) нет.
5. CPU роутера ВО ВРЕМЯ speedtest: RCI `/rci/show/system` → `cpuload`, семпл каждые 2-3 с.

Итог кейса: при прямых 90 и raw VPS 545 — узкое место **CPU роутера MT7621 (MIPS 880 МГц, KN-1713)**: крипта WG/AWG без аппаратного ускорителя, потолок ~15-25 Мбит/с (AWG медленнее WG из-за junk-пакетов; CPU пики 50-90% ровно в тесте). Обход: VLESS/sing-box на самом устройстве (крипта на CPU телефона/ПК), роутер на MT7981/Filogic 820 (300-500 Мбит/с), либо снизить Jc.

## Pitfalls

- bivlked/amneziawg-installer = AWG 2.0 only (wire-incompatible with Keenetic
  v1.0; also invasive: UFW, reboots, removes unattended-upgrades).
- Docker `amneziavpn/amnezia-wg` (single tag `latest`, 2023-10-03 = v1.0-era)
  is NOT self-contained: contains wireguard-go/wg/wg-quick only; still needs
  the amneziawg kernel module on the host.
- Old v1.0.* module tags (e.g. v1.0.20241112) may demand the FULL kernel
  source tree symlinked as `kernel`; recent v1.0.* tags (2025+) build from
  headers with the compat patch.
- Amnezia client master deploys AWG 2.0; the v1.0-era server scripts live at
  tag 4.8.11.3 (`client/server_scripts/awg/`: configure_container.sh,
  run_container.sh, start.sh, template.conf) if you need the official
  reference recipe.

## Verify

- Server: `awg show` (peer + handshake), tcpdump on wg0 shows real forwarded
  traffic BOTH ways (not just keepalives), iptables FORWARD counters grow.
- Client: browse from a policy-bound device; VPS sees src 10.7.0.x traffic.

## Support files

- `references/amneziawg-v1-ubuntu2204.md` — exact build commands, compat patch
  transcript, tools download, defaults, amnezia-client script locations.
