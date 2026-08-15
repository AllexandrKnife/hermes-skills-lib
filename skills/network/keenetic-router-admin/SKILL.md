---
name: keenetic-router-admin
version: 1.0.0
description: Use when configuring a Keenetic router (KeeneticOS).
critic_status: done
---
## When to Use

Use when configuring a Keenetic router (KeeneticOS).


# Keenetic Router Admin (KeeneticOS)

Access and configure Keenetic routers (KeeneticOS 4.x, e.g. KN-1211 "4G", mips). Covers telnet CLI, web API auth, and slow-speed diagnosis.

## Access paths (easiest first)

0. **Быстрый рекон портов**: `ping -c 2 <ip>; for p in 22 23 80 443; do timeout 2 bash -c "echo > /dev/tcp/<ip>/$p" 2>/dev/null && echo "$p OPEN"; done`

1. **Telnet CLI (port 23)** — usually enabled. Plain `nc` piping FAILS: input races the prompt. Use an interactive socket script: `scripts/keen_telnet_cli.py` (waits for `Login:`/`Password:` prompts, handles `--More--` paging). Login: `admin` / user password. Prompt: `(config)>`.
2. **Web API (80/443)** — challenge-response auth, see below. Use when you need RCI/JSON endpoints the CLI lacks.
3. **SSH (port 22)** — closed by default on Keenetic.

## Telnet CLI essentials

- Working commands: `show version`, `show interface`, `show wan`, `show dns`, `show running-config` (полный конфиг — работает и на 5.x).
- На KeeneticOS 5.x `show ip` возвращает пусто — используй RCI: `/rci/show/ip/route` (таблица маршрутов), `/rci/show/ip/hotspot` (клиенты, JSON), `/rci/show/interface/` (все интерфейсы).
- `show interface` = полный dump — grep for `channel`, `bandwidth`, `busy-channels`, `speed`, `bitrate`, `ssid`, `encryption`, `role`.
- Output paginates with `More` — must send space to continue (script handles this).
- List subcommands available in a context: `list` (e.g. after `interface WifiMaster0`).
- **Change WiFi channel**:
  ```
  interface WifiMaster0
  channel 11
  exit
  system configuration save
  ```
  Confirmation: `Network::Interface::Mtk::WifiMaster: "WifiMaster0": channel set to 11.` Verify afterwards with `show interface WifiMaster0`.
- **Do NOT rely on these commands** (absent on KN-1211 / KeeneticOS 4.3.8): `show wifi`, `show cpu`, `show memory`, `show system`, `show hosts`, `show arp`, `show route`, `show log`, `show trafficcontrol`, `show qos`, `scan`, `station`. Discover real ones with `list`.

## KeeneticOS 5.x (KN-1713 Extra) — differences from 4.3.8 notes

Observed on Keenetic Extra KN-1713 @192.168.1.1, KeeneticOS 5.0.8 (release 5.00.C.8.0-1):

- `show ip` returns EMPTY (was JSON wans/wbk on 4.3.8) — use RCI instead.
- `show running-config` WORKS — full config dump: WG peers (`allow-ips`),
  `ip global <priority>` per interface, `ip policy PolicyN` blocks, `ip hotspot`
  host bindings, `ip name-server ... on <iface>`. Fastest way to inspect WG config.
- `list` absent in `(config-if)>` context; `show route` / `show configuration` /
  `show startup-config` absent.
- RCI endpoints that work (auth via `scripts/keen_api_auth.py`):
  - `/rci/show/interface/WireguardN` — tunnel runtime: peer pubkey, endpoint,
    rxbytes/txbytes, last-handshake, online, defaultgw
  - `/rci/show/ip/hotspot` — LIVE clients: mac/ip/hostname/priority/active
  - `/rci/show/ip/route` — ROUTE TABLE (destination/interface/gateway/metric) —
    decisive for routing diagnosis
  - `/rci/show/system`, `/rci/show/interface/`
  - 404/empty on 5.0.8: show/route, show/dhcp, show/ipv4, show/ipv6, show/dns,
    export/configuration, show/ip (returns `{}`)
- Pitfall: `POST /rci/interface/WireguardN {"defaultgw": true}` → HTTP 200 `{}`
  but routing unchanged — `defaultgw` is derived from route selection, NOT a
  settable flag. Do not rely on it.

## WireGuard client diagnosis ("connected but no traffic")

Config model (from `show running-config`):
- WG client connection = `interface WireguardN` (Wireguard0..5 seen)
- "Разрешённые сети" = `allow-ips 0.0.0.0 0.0.0.0` in the `wireguard peer` block
- default-route participation = `ip global <priority>`. Observed on 5.0.8:
  LOWER value = HIGHER preference (16033 beats 32067). The new tunnel
  (16033) DID carry the Xiaomi's traffic while GeR (32067) was still in the
  policy — the VLESS session and a stalled Google download both appeared on
  the new VPS's counters. So the 5.39.255.242 case was NOT a
  policy-selection problem: the real killer was TSPU DPI stalling WG data
  packets (see MTU/MSS stall signature below); removing GeR from Policy1 was
  a diagnostic A/B step, not the fix (the fix was AmneziaWG). Practical
  rule: with multiple `permit global` entries, use A/B (leave ONE) to find
  which tunnel carries traffic — but a tunnel with fresh handshakes AND
  retransmission stalls is a DPI problem, not a routing one.
- per-device VPN = `ip policy PolicyN` (`permit global WireguardN`) + binding
  `ip hotspot host <mac> policy PolicyN`

Diagnosis order when tunnel is up but the server sees no traffic:
1. Server: `wg show` (fresh handshake?), `/proc/net/dev` wg0 counters, FORWARD
   counters, `sysctl net.ipv4.conf.*.rp_filter` (2 = loose, OK). Only keepalives
   (~1 pkt/25 s) arriving = the client is not routing traffic into the tunnel.
2. Router `/rci/show/ip/route`: if `0.0.0.0/0` still → PPPoE0 and the test device
   is not policy-bound, the tunnel carries nothing. Fix is device binding or
   `ip global` priority — NOT server-side NAT.
3. `/rci/show/ip/hotspot`: identify the test device (name/priority/active). The
   device the user tests from is often NOT the one bound to the VPN policy.
4. Keenetic does not answer ICMP on its tunnel IP by default — ping loss to the
   client IP (e.g. 10.7.0.2) is normal, not a fault. `defaultgw: no` on all WG
   interfaces in `show interface` is also normal — route table is ground truth.
5. Server-side fix if `wg-quick` dies with `ip: command not found`:
   `apt-get install -y iproute2` — `apt autoremove` can remove it on minimal
   Ubuntu images, which silently breaks wg-quick.

Client config lesson (user correction): a full-tunnel WG client config MUST
include `DNS = <server>`; after import into Keenetic, verify it survived as
`ip name-server X "" on WireguardN` in running-config — the imported value may
not match what was in the file.

See `references/keenetic-5x-wg-diagnosis.md` for the worked case (endpoints,
payloads, root-cause trace).

## Экспорт туннелей (перенос WG/AWG на другое устройство, кейс 08.2026)
- Приватный ключ роутера для WG-интерфейса НЕ экспортируется: ни `show running-config` (показывает только public key пира и прешер), ни RCI `/rci/show/interface/WireguardN` (есть public-key клиента, listen-port, peer — приватного ключа НЕТ). Проверено 08.2026 при переносе GeR с Keenetic на Cudy.
- Перенос = сгенерировать НОВУЮ пару ключей на целевом устройстве (`wg genkey` / `wg pubkey`) и добавить новый пир на сервере (AllowedIPs = новый адрес /32, PresharedKey тот же). Старый клиент продолжает работать.
- Полный конфиг WG из running-config: интерфейс (описание, ip address, mtu, ip global приоритет, keepalive, preshared-key) + peer (public key сервера, endpoint, allow-ips 0.0.0.0 0.0.0.0). Политика устройств — `ip policy PolicyN` (permit global WireguardN).
- Серверная сторона может жить в docker (контейнер amnezia-wireguard = ОБЫЧНЫЙ WG, не путать с amnezia-awg): wg0.conf в контейнере, порт слушается через docker-proxy.
- Детали кейса: openwrt-singbox-home-gateway/references/wg-migration-keenetic-to-cudy.md

## WireGuard client edit pitfalls (5.0.8)

- **Edit name-server (CRITICAL gotcha)**: short form (`ip name-server 1.1.1.1`)
  silently no-ops. Inside `interface WireguardN` context use the FULL form:
  `no ip name-server 1.1.1.1 "" on Wireguard5` →
  `ip name-server 45.134.15.185 "" on Wireguard5` → `exit` →
  `system configuration save`. Confirmation:
  `Dns::InterfaceSpecific: "Wireguard5": name server ... deleted/added`.
- **DNS reachability (RU)**: the router resolves DNS via its OWN default route
  (PPPoE direct), not through the tunnel. 1.1.1.1/8.8.8.8 are TSPU-blocked on the
  direct path → DNS dead → devices see "no internet through WG", while a VLESS
  proxy from the same phone works fine (remote DNS). Use own AdGuardHome
  (45.134.15.185) or Yandex 77.88.8.8 as the WG connection's DNS.
- **MTU/MSS stall signature**: tcpdump on the SERVER's wg0 shows server→client
  segments retransmitted (same seq, no ACK progress) while FORWARD counters grow —
  the path works but large segments are dropped. `ip tcp adjust-mss pmtu` depends
  on ICMP PMTU messages that home ISPs/TSPU filter. It did NOT fix the case here — the stall was TSPU DPI on the WG wire
  (symmetric loss; even small 986-byte segments retransmitted with no ACK
  progress). Decision rule: if the same segment is retransmitted with no ACK
  progress while FORWARD counters grow, and an MSS clamp does not help —
  assume DPI and migrate the tunnel to AmneziaWG v1.0 (skill `amneziawg-v1-server`).

## AmneziaWG on 5.0.x (import-only)

- The WireGuard connection editor has NO junk fields (SPA bundle has no
  "amnezia"/"junk" strings) — AWG configs are applied ONLY via
  "Other Connections → WireGuard → Import from a file" (Keenetic 4.3.4+
  parses Jc/Jmin/Jmax/S1/S2/H1-H4 from the imported file). Protocol v1.0
  only; 1.5/2.0 need KeeneticOS 5.1 Alpha 3+.
- Headless import: the file-picker button opens a NATIVE dialog (no DOM file
  input appears; browser_click swallows it). Use the RCI endpoint instead:
  `POST /rci/interface/wireguard/import` body
  `{"import": "<base64 of config>", "name": "", "filename": "x.conf"}`
  → 200 `{"intersects": "Wireguard5", "created": "Wireguard6", ...}`.
  The junk params land in running-config as a single line:
  `wireguard asc <Jc> <Jmin> <Jmax> <S1> <S2> <H1> <H2> <H3> <H4>`.
- Import creates the interface DISABLED and WITHOUT `ip global` — until a
  priority is set, the policy rejects it with
  `Network::PolicyTable error: no such global interface`. Correct order:
  `interface Wireguard<new>` → `ip global <priority>` (LOWER = higher
  preference; match the replaced tunnel's old value) → exit → policy
  `permit global Wireguard<new>` → `interface Wireguard<new>` → `up` → THEN
  `no interface Wireguard<old>` (the enable fails with "network ... conflicts
  with interface <old>" while the old interface still owns the subnet) →
  `ip name-server <RU-reachable> "" on Wireguard<new>` →
  `system configuration save`.
- UI automation: the connection-settings dialog renders inside
  `#cdk-overlay-1`; when browser_click fails with "element is covered",
  click the overlay element via browser_console JS instead of refs.
- The web editor's DNS field can show a stale value (1.1.1.1) even after a CLI
  change — trust running-config, not the form.

## Web API auth (x-ndw2-interactive)

Reverse-engineered from the SPA bundle (`main.*.js`, search `getEncryptedPassword`). Script: `scripts/keen_api_auth.py`.

1. `GET /auth` → 401 with headers `X-NDM-Challenge`, `X-NDM-Realm` + `Set-Cookie` session. **Keep the cookie jar across steps** — losing it gives `400 X-Detail: 0x2021, no session`.
2. `d = MD5("login:realm:password").hexdigest()`
3. `enc = SHA256(challenge + d).hexdigest()` (hex, lowercase)
4. `POST /auth` JSON `{"login": ..., "password": enc}` with cookie jar → 200 + session cookie.

Pitfalls: plaintext password → 400. `GET /` (panel root) does NOT issue the session cookie — use `GET /auth`. Also note: an initial `POST /auth` before any GET returns the same 400.

## WireGuard/AmneziaWG на KeeneticOS 5.x (KN-1713 и др.)

- Импорт конфига WireGuard/AmneziaWG: `POST /rci/interface/wireguard/import` c JSON `{"import": "<base64 файла>", "name": "", "filename": "x.conf"}` (auth — keen_api_auth.py). Ответ `{"created": "WireguardN", "intersects": "<старый>"}`. Созданный интерфейс по умолчанию DOWN.
- AWG-конфиг (Jc/Jmin/Jmax/S1/S2/H1-H4) роутер принимает при импорте — в running-config появляется строка `wireguard asc Jc Jmin Jmax S1 S2 H1 H2 H3 H4`. Отдельного UI-переключателя AmneziaWG в 5.0.8 нет — только импорт.
- После импорта ОБЯЗАТЕЛЬНО (иначе не работает):
  1. `interface WireguardN` → `ip global <приоритет>` (без этого в `ip policy` нельзя: ошибка "no such global interface") → `up` → `exit`
  2. `ip policy PolicyN` → `permit global WireguardN` → `exit`
  3. `interface WireguardN` → `ip name-server <dns> "" on WireguardN` (обязателен синтаксис `"" on <iface>`) → `exit`
  4. `system configuration save`
- Приоритет ip global: МЕНЬШЕ = ВЫШЕ. Если в политике несколько `permit global`, побеждает меньший номер (16033 < 32067).
- Привязка устройств к политике: `host <mac> policy PolicyN` (секция `ip hotspot`).
- Удаление интерфейса: `no interface WireguardN`. Подсеть занята интерфейсом → `up` нового с той же сетью не пройдёт, пока старый не удалён.
- Проверка фактического выбора туннеля: `/rci/show/ip/route` (только main table), per-host трафик — счётчики на серверах туннелей. При сомнениях — A/B: оставить в политике один `permit global`.

## VLESS/Reality и прочие не-WG протоколы — нативно НЕ поддерживаются

Список VPN-клиентов KeeneticOS (Интернет → Другие подключения): WireGuard,
AmneziaWG (только импорт), OpenVPN, L2TP/IPsec, PPTP, SSTP. VLESS/Reality,
Shadowsocks, Trojan отсутствуют (проверено 08.2026, KeeneticOS 5.0.8).

Варианты:
1. **Entware + sing-box на роутере** (нужна USB-флешка):
   `wget -O - http://entware.net/installer/installer-generic.sh | sh` →
   `opkg update && opkg install sing-box` (fallback `xray`) → клиентский конфиг
   VLESS+Reality (mixed inbound), автозапуск `/opt/etc/init.d/S99` (rc.unslung).
   Ограничение: MT7621 (KN-1713) даёт 15-25 Мбит/с на WG-крипте — Reality
   (TLS+XTLS) будет в той же полосе или ниже; браузинг/YouTube ок, 4K/торренты нет.
2. **Клиент на устройстве** (v2rayNG/sing-box на телефоне/ПК) — готовый конфиг
   vdska уже есть в WSL (скилл wsl-vpn-on-demand).
3. **Гейтвей вместо/перед Keenetic** для 300+ Мбит/с: OpenWrt-роутер на MT7981
   или N100 mini-PC — модели/цены/критерии: `references/vpn-gateway-hardware.md`.

## Slow-speed diagnosis checklist

### Туннель медленный, но прямой интернет быстрый (изоляция узкого места)

Порядок замеров (каждый отсекает свой сегмент):
1. Прямой speedtest БЕЗ туннеля (устройство вне VPN-политик или `permit global PPPoE0` в политике) → потолок ISP. В кейсе: 90 Мбит/с — ISP и WiFi ни при чём.
2. Альтернативный туннель (другой сервер/протокол) → отсекает конкретный сервер. В кейсе: GeR (обычный WG) 21.45 vs новый AWG 15.52 — оба ~в одной полосе.
3. Raw-скорость VPS: `curl -o /dev/null -w '%{speed_download}' https://cachefly.cachefly.net/100mb.test` — 545 Мбит/с. Cloudflare speed-эндпоинт (`speed.cloudflare.com/__down`) с VPS часто не отвечает — не показатель.
4. UDP-путь дом→VPS в обход туннеля: `iperf3 -s` на VPS, `iperf3 -u -b 100M` с домашнего клиента → 54-100 Мбит/с без потерь = UDP-шейпинга (TSPU/ISP) нет.
5. CPU роутера ВО ВРЕМЯ speedtest: RCI `/rci/show/system` → `cpuload`, семпл каждые 2-3 с (CLI `show system` на 5.x нет, RCI работает).

Вывод по кейсу: при прямых 90 Мбит/с, raw VPS 545 и UDP 54-100 — узкое место **CPU роутера**: MT7621 (MIPS 880 МГц, KN-1713) гонит WG/AWG крипту без аппаратного ускорителя, потолок ~15-25 Мбит/с. Симптом: туннель несёт 15-20 Мбит/с (счётчики на сервере), CPU роутера в пиках 50-90% ровно во время теста, у ВСЕХ устройств одинаково — общий элемент роутер, а НЕ буферы клиентов (версию «дефолтные TCP-буферы телефона» пользователь опроверг: другие устройства дают те же 15-20).

КЛЮЧЕВОЙ ФАКТ (подтверждён синхронным замером счётчиков): VPN-клиент на самом устройстве (v2rayNG/sing-box, VLESS) НЕ идёт через туннель роутера — его соединение к endpoint'у VPS выходит напрямую (роутер не заворачивает трафик к собственному endpoint'у туннеля в туннель). «speedtest с VLESS = 60-90, без VLESS = 15-20» — это НЕ ускорение туннеля, а его ОБХОД: во время VLESS-теста счётчики туннеля ≈ 0. Снаружи не отличить (2ip.ru покажет IP VPS в обоих случаях) — только счётчики.

Метод диагностики: синхронные мониторы шагом 2 сек — (1) на сервере туннеля дельты `/proc/net/dev` для tunnel-интерфейса (ВНИМАНИЕ: RX = от клиента = upload клиента, TX = к клиенту = download клиента — не перепутать, частая ошибка), (2) CPU роутера `/rci/show/system` → cpuload. Пользователь гоняет speedtest по фазам (без VPN / с VLESS) — коррелируем, какая фаза реально грузит туннель и CPU. Признак «трафик мимо туннеля»: speedtest 60-90, счётчики туннеля ~0. Не делать выводов по одной speedtest-цифре.

Обход потолка: роутер на MT7981/Filogic 820 (300-500 Мбит/с) либо VLESS на устройстве (обход, не ускорение туннеля). Снижение Jc у AWG — не проверено, не обещать.

### Классический чек-лист (медленный сам роутер)

1. **WAN port speed** (`show interface`, port role `ISP`/`inet`): FastEthernet = **100 Mbps hard cap**. KN-1211 has FastEthernet only — cannot exceed 100 Mbps even with a faster tariff. If port shows `speed: 100` and tariff is higher, the router is the bottleneck.
2. **WiFi band/channel**: KN-1211 = single 2.4 GHz radio, 802.11n (`bitrate: 300000000` = 300 Mbps theoretical, 60-90 real). Check `busy-channels` — if all channels 1-7 are listed busy, the band is congested; channel switch helps marginally, saturation remains. Models without 5 GHz physically cannot fix crowded 2.4 GHz.
3. **WireGuard tunnels** (`show ip` JSON `wbk` list, or `show interface` for `Wireguard0/1`): on mips routers active WG tunnels degrade throughput noticeably when traffic routes through them. Check whether default route / clients actually use them.
5. **Температура радио** (`temperature: N` в show interface WifiMaster*) — выше 70°C = перегрев, троттлинг.
6. **DNS proxy** (`ndnproxy` on 1.1.1.1): low request counts → not the bottleneck; skip unless request volume is high.
5. Measure real speed from a client IN the LAN (phone/PC): from WSL/NAT you cannot reach the internet through the router, that's expected.

## DNS-ранги (KeeneticOS)

Ранги назначаются АВТОМАТИЧЕСКИ: DNS, полученный через интерфейс (PPPoE/DHCP/WG) → rank 0 (наивысший). Ручной команды изменения ранга в CLI НЕТ (проверено: dns-контекст, интерфейсы, RCI). Варианты:
- `no ip name-servers` на интерфейсе — убрать DNS провайдера полностью (сервер исчезнет из списка)
- Веб-панель: Интернет → Другие подключения → DNS-серверы — ручной порядок приоритета поверх автоматического ранга
- Контекст `dns` → `(config-dnspx)>`: filter, intercept, rebind-protect

## Pitfalls / user preferences

- **Never change router settings without explicit user confirmation.** User first asked for a report only ("просто отчёт"), then explicitly ordered the channel change. Offer the change, wait for approval.
- **Точка возврата перед ЛЮБЫМ изменением (предв. действие):** сохранить текущее состояние `show running-config` в файл на WSL до правок. Откат по эталону — минуты; восстановление из памяти — часы. Особенно для связок interface/policy/hotspot (WG: ip global + permit + name-server — три шага, любой пропущенный = неработающий туннель).
- User prefers fast targeted checks with short timeouts — no long interactive probes; they will interrupt with «стоп».
- Router password: prompt for it (env var `KEEN_PASS`); do not hardcode credentials into skills/memory.
- CLI has **no WiFi scan** (`scan` doesn't exist, `rf` only exposes `e2p`). Web UI has a `wifi-analyzer` (present in SPA bundle), but a working API scan call was NOT confirmed — if needed, dig the RCI method from the bundle before promising results.

## Support files

- `scripts/keen_telnet_cli.py` — interactive telnet CLI runner (prompt-waiting + paging).
- `scripts/keen_api_auth.py` — web API challenge-response auth, saves cookie jar.
- `references/kn-1211-diagnostics.md` — observed session detail: model, working/absent commands, findings.
- `references/keenetic-5x-wg-diagnosis.md` — stage 1 of the worked case: policy/binding analysis, RCI/CLI endpoint inventory, server-side facts (incl. iproute2/autoremove fix).
- `references/keeneticos5-wireguard-diagnostics.md` — stage 2: DNS root cause (TSPU-blocked 1.1.1.1), `ip name-server` edit syntax, MTU/MSS stall signature, SPA endpoint discovery.
