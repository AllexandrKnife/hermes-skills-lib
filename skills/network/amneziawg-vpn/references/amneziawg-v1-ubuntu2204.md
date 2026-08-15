# AmneziaWG v1.0 server on Ubuntu 22.04 (kernel 5.15) — worked recipe

Worked 2026-08 on VPS 5.39.255.242 (abstation.net, Ubuntu 22.04.2, kernel
5.15.0-76-generic, KVM). Goal: replace TSPU-blocked WireGuard with AWG v1.0
for a Keenetic 5.0.8 client (Keenetic speaks only AWG v1.0 wire protocol).

## Repos / tags (verified alive 2026-08)

- Kernel module: `amnezia-vpn/amneziawg-linux-kernel-module`
  - tag `v1.0.20260725` — latest v1.0 line (v1.0.* maintained alongside v3.0.*)
  - OLD name `amnezia-vpn/amneziawg` → GitHub API 404 (renamed)
  - tag `v1.0.20241112` — builds against FULL kernel source only
    (symlink `kernel` → kernel source); recent v1.0.* tags build from headers
- Tools: `amnezia-vpn/amneziawg-tools` releases → `ubuntu-22.04-amneziawg-tools.zip`
  (tag v1.0.20260618-2; contains static `awg` + `awg-quick` + .sha256)
- Amnezia client v1.0-era server scripts: tag `4.8.11.3`,
  `client/server_scripts/awg/` (Dockerfile, configure_container.sh,
  run_container.sh, start.sh, template.conf) — the official reference recipe
  (uses docker `amneziavpn/amnezia-wg:latest` = 2023-10-03, v1.0-era, but the
  image is NOT self-contained: only wireguard-go/wg/wg-quick inside; the host
  still needs the amneziawg kernel module)

## Build steps

```bash
apt-get install -y build-essential   # make/gcc
# linux-headers-$(uname -r) must be present

cd /tmp
curl -sL "https://github.com/amnezia-vpn/amneziawg-linux-kernel-module/archive/refs/tags/v1.0.20260725.tar.gz" -o awg.tar.gz
tar xzf awg.tar.gz
cd amneziawg-linux-kernel-module-1.0.20260725/src
make          # amneziawg.ko
make install  # /lib/modules/.../kernel/net/amneziawg.ko + depmod
```

## The timer_delete compat bug (Ubuntu 22.04 / 5.15)

`make` fails on 5.15 with:

```
device.c:93: error: implicit declaration of function 'timer_delete' [-Werror=implicit-function-declaration]
```

Root cause: `compat/compat.h` defines the timer_delete shim only when
`!defined(ISUBUNTU2204)` — but 5.15.0-76 does NOT have timer_delete
(introduced in kernel 6.2) despite the Ubuntu-22.04 exclusion.

Fix — edit `src/compat/compat.h`, change:

```c
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 1, 91) && !defined(ISUBUNTU2004) && !defined(ISUBUNTU2204) && !defined(ISRHEL9)
```
to:
```c
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 1, 91) && !defined(ISUBUNTU2004) && !defined(ISRHEL9)
```

Then `make clean && make`. Do NOT add your own static-inline shim at the end
of compat.h — `timer_delete_sync` is already a macro there and the duplicate
function definition breaks the build.

## Tools

```bash
curl -sL "https://github.com/amnezia-vpn/amneziawg-tools/releases/download/v1.0.20260618-2/ubuntu-22.04-amneziawg-tools.zip" -o awgtools.zip
unzip -o awgtools.zip -d awgtools
# awgtools/ubuntu-22.04-amneziawg-tools/{awg,awg-quick}
cp awgtools/ubuntu-22.04-amneziawg-tools/awg awgtools/ubuntu-22.04-amneziawg-tools/awg-quick /usr/local/bin/
```

## Kernel module swap

```bash
grep -c wireguard /lib/modules/$(uname -r)/modules.builtin   # 0 → module, not builtin
rmmod wireguard                                              # standard WG is a module on 22.04 cloud
echo "blacklist wireguard" > /etc/modprobe.d/blacklist-wireguard.conf
modprobe amneziawg
```

Link kind is "amneziawg" (`src/device.c`: `.kind = KBUILD_MODNAME`), genl
attrs `WGDEVICE_A_JC/JMIN/JMAX/S1/S2` (u16) and `H1..H4` (NUL_STRING).
Standard `wg-quick` cannot create the interface — `awg-quick` is required.

## Server config (reuse existing WG file, add junk keys)

```ini
[Interface]
PrivateKey = <server key>        # Curve25519 — WG keys are compatible
Address = 10.7.0.1/24
ListenPort = 51871
Jc = 5
Jmin = 30
Jmax = 50
S1 = 16
S2 = 16
H1 = 1234567890
H2 = 987654321
H3 = 555555555
H4 = 111111111
MTU = 1420

[Peer]
PublicKey = <client pub>         # router keypair (10.7.0.2)
AllowedIPs = 10.7.0.2/32
PersistentKeepalive = 25
```

Same junk values MUST be in the client config. Existing iptables
FORWARD/MASQUERADE for wg0 need no changes.

CRITICAL config location: `awg-quick` reads `/etc/amnezia/amneziawg/<iface>.conf`,
NOT /etc/wireguard/ (`awg-quick: ".../awg0.conf" does not exist` otherwise).
Copy the file there: `mkdir -p /etc/amnezia/amneziawg && cp ... && chmod 600`.
Up: `awg-quick up <iface>` (verify junk with `awg show` — jc/jmin/jmax/s1/s2/
h1-h4 lines).

systemd (the tools zip ships no unit):
```ini
# /lib/systemd/system/awg-quick@.service
[Unit]
Description=AmneziaWG via awg-quick(8) for %I
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/awg-quick up %i
ExecStop=/usr/local/bin/awg-quick down %i
[Install]
WantedBy=multi-user.target
```
`systemctl enable --now awg-quick@<iface>` (down the iface first if you
brought it up manually).

## Client config (original AmneziaWG format → Keenetic import)

```ini
[Interface]
PrivateKey = <router key>
Address = 10.7.0.2/24
DNS = 45.134.15.185
Jc = 5
Jmin = 30
Jmax = 50
S1 = 16
S2 = 16
H1 = 1234567890
H2 = 987654321
H3 = 555555555
H4 = 111111111

[Peer]
PublicKey = <server pub>
PresharedKey = <psk>
AllowedIPs = 0.0.0.0/0
Endpoint = 5.39.255.242:51871
PersistentKeepalive = 25
```

Import via RCI (headless): POST /rci/interface/wireguard/import with
`{"import": "<base64>", "name": "", "filename": "x.conf"}` → creates
Wireguard6; router stores junk as `wireguard asc 5 30 50 16 16 1234567890
987654321 555555555 111111111`. Post-import on the router: `ip global
<priority>` (import doesn't set it; policy errors "no such global interface"
without it), `permit global Wireguard6` in the policy, `up`, delete the old
interface AFTER the new one owns the subnet, `ip name-server <ip> "" on
Wireguard6`, `system configuration save`.

## Interop facts

- Keenetic 4.3.4+ reads ALL junk params from the imported file; the 5.0.8
  connection editor has no Jc/Jmin/Jmax fields and the SPA has no
  "amnezia"/"junk" strings → import-only path.
- Amnezia client master = AWG 2.0 deploy; 4.8.10.0/4.8.11.3 = last v1.0 line
  (Habr recipe, March 2026).
- bivlked/amneziawg-installer (1k+ stars) installs AWG 2.0 for Ubuntu
  24.04+/Debian 12+ with UFW/reboots — wrong for Keenetic v1.0 and invasive.
