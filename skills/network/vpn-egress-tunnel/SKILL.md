---
name: vpn-egress-tunnel
description: "Use when Туннель WSL→VPS: обход CF-блокировок,"
critic_status: done
version: 1.0.0
---

# VPN Egress Tunnel (WSL → свой VPS)

## Когда использовать

- Российский IP блокируется Cloudflare/сервисами: mcp.exa.ai, api.exa.ai, зарубежные API отдают 403 «Attention Required»
- Нужен выходной IP зарубежного VPS для поиска/API, без включения VPN на Windows-хосте
- Требуется маскировка туннеля под обычный HTTPS (корпоративный KES/DLP не должен видеть VPN-паттерн)
- Настройка автозапуска туннеля в WSL (нет systemd — PID 1 = init)

## Диагностика: CF-блокировка по IP

```bash
curl -s -m 8 -o /dev/null -w "%{http_code}\n" "https://mcp.exa.ai/mcp"   # 403 = заблокирован
curl -s -m 10 https://ipinfo.io/json | head -8                           # текущий выходной IP
```

Признак CF-блока: ответ `403` с `server: cloudflare` и HTML «Attention Required!».
**Googlebot-UA обход (`User-Agent: Mozilla/5.0 (compatible; Googlebot/2.1; ...)`) работает только временно** — Cloudflare ужесточает WAF через часы, и тот же IP снова получает 403 даже с Googlebot-UA. Не полагаться на него как на решение.

**JA3-фингерпринт**: при прямых HTTP-вызовах Python `urllib` получает 403 там, где `curl` проходит 200 (Cloudflare режет по TLS-отпечатку). Всегда использовать `curl` (или subprocess-вызов curl), не urllib/requests без спец-фингерпринта.

## Выбор транспорта

| Критерий | WireGuard | sing-box VLESS+Reality |
|---|---|---|
| Маскировка | Нет (UDP-паттерн, сигнатуры WG) | TLS 1.3 к легитимному SNI (apple.com), неотличим от HTTPS |
| KES/DLP | Виден как VPN (порт, UDP, handshake) | Видно только TLS:443 к сайту |
| Простота | wg-quick, 2 файла | sing-box бинарник + JSON |
| Порты | 51820/54711 (нестандарт) | 443/39261 (любой) |
| Скорость | Быстрый | ~та же (Reality) |

Для корпоративной машины с KES/KSC — sing-box Reality. Для «просто дать Exa работать» на своей машине — WireGuard хватает.

## WireGuard-вариант (WSL-клиент)

### Установка

```bash
apt-get update
apt-get install -y wireguard-tools resolvconf
```

**Pitfall: apt зависает на dpkg-триггере** `linux-update-5.15.0-1032-realtime` (пересборка initramfs). Пакеты при этом могут уже установиться. Лечится:
```bash
dpkg --configure -a        # дожать зависший триггер (долго, initramfs)
apt-get install -y wireguard-tools
```
Если `wg` уже в `/usr/bin/wg` — установка прошла, `dpkg --configure -a` только чинит состояние.

WSL2 ядро 6.6 имеет `/dev/net/tun` — штатный wireguard работает.

### Клиентский конфиг `/etc/wireguard/wg0.conf` (full tunnel)

```
[Interface]
PrivateKey = <client-private>
Address = 10.77.77.X/32
DNS = 10.77.77.1

[Peer]
PublicKey = <server-public>
Endpoint = <VPS-IP>:<port>
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

`AllowedIPs = 0.0.0.0/0` — полный туннель (весь трафик WSL через VPS). Серверная сторона (генерация ключей, добавление peer с `AllowedIPs = <client>/32` на VPS) — см. homelab-wireguard-vpn.

```bash
wg-quick up wg0
wg show wg0 | grep -E "handshake|endpoint"   # latest handshake < 1 min = ОК
curl -s -m 10 https://ipinfo.io/json | head -8  # IP = VPS
```

## sing-box VLESS+Reality-вариант (рекомендуемый для KES/DLP)

### Бинарник: копировать С СЕРВЕРА, не с GitHub

GitHub-release сборка может быть обрезана (нет tun-полей, часть route rules). На VPS стоит полный бинарник:

```bash
sshpass -p '<pass>' scp root@<VPS>:/etc/s-box/sing-box /usr/local/bin/sing-box
chmod +x /usr/local/bin/sing-box && sing-box version
```

### Взять параметры с сервера

```bash
ssh root@<VPS> 'python3 -c "
import json
cfg = json.load(open(\"/etc/s-box/sbox.json\"))
for o in cfg.get(\"outbounds\", []):
    if o.get(\"type\") == \"vless\":
        print(json.dumps(o))"'
```
Нужны: server, server_port, uuid, flow, tls.server_name, tls.reality.public_key, short_id.

### Конфиг: mixed-прокси вместо tun

**Pitfall: sing-box 1.13 убрал legacy inbound fields** (`address`→`inet4_address`→`address`, `dns_mode` unknown, `sniff` deprecated). Проще и надёжнее — mixed (HTTP+SOCKS) прокси на localhost, без tun:

```json
{
  "log": { "level": "info", "timestamp": true },
  "inbounds": [
    { "type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 1080 }
  ],
  "outbounds": [
    {
      "type": "vless", "tag": "vless-reality",
      "server": "<VPS-IP>", "server_port": <port>,
      "uuid": "<uuid>", "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true, "server_name": "<sni>",
        "utls": { "enabled": true, "fingerprint": "chrome" },
        "reality": { "enabled": true, "public_key": "<pub>", "short_id": "<sid>" }
      }
    },
    { "type": "direct", "tag": "direct" }
  ],
  "route": { "final": "vless-reality", "auto_detect_interface": true }
}
```

**Pitfall: кастомные сборки не принимают route rule types** (`private`, `ip_is_private`, `ip_cidr`, `domain_suffix` — «unknown rule type»). Для mixed-прокси route.rules не нужны — весь трафик через final.

### Проверка

```bash
sing-box check -c /etc/sing-box/config.json
sing-box run -c /etc/sing-box/config.json &   # фоном
curl -s -m 15 -x http://127.0.0.1:1080 https://ipinfo.io/json   # IP = VPS
curl -s -m 15 -x http://127.0.0.1:1080 -o /dev/null -w "%{http_code}\n" \
  -X POST https://mcp.exa.ai/mcp -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}'  # 200 = Exa доступен
```

### Прокси в окружение WSL

**Pitfall (14.08.2026): .bashrc guard ломает `cat >>`.** Стандартный `/root/.bashrc` содержит `[ -z "$PS1" ] && return` — для не-интерактивного shell (в т.ч. terminal Hermes с `auto_source_bashrc`) всё, добавленное В КОНЕЦ файла, НЕ выполняется: `cat >>` в конец не работает, env-прокси остаётся пустым. Класть export'ы ДО guard (в начало .bashrc, после `export EDITOR/VISUAL`):

```bash
export http_proxy=http://127.0.0.1:1080 https_proxy=http://127.0.0.1:1080 all_proxy=socks5://127.0.0.1:1080
export HTTP_PROXY=http://127.0.0.1:1080 HTTPS_PROXY=http://127.0.0.1:1080 ALL_PROXY=socks5://127.0.0.1:1080
export no_proxy=localhost,127.0.0.1,api.deepseek.com,api.github.com,github.com,checko.ru,.local,.internal
export NO_PROXY=$no_proxy
```

Проверка: `bash -c '. /root/.bashrc; echo $http_proxy'` должен показать прокси, не пусто. `no_proxy` обязателен — иначе DeepSeek/GitHub/RU-сервисы (checko) пойдут через туннель (лишняя задержка или отказ).

### On-demand режим (подъём по требованию + авто-падение)

Постоянный туннель не нужен: поднимается, когда скилл дёргает exa/tavily, падает через 60 сек бездействия, и только если выходной IP российский. Скрипты в `~/.hermes/scripts/`:

- `egress-up.sh` — проверяет IP (ipinfo, `--noproxy '*'`), если RU → поднимает sing-box (если порт не слушает), обновляет timestamp, запускает watchdog. Идемпотентен. Использует ЕДИНЫЙ с vpn-tun.sh pidfile `/var/run/sing-box.pid` — если туннель уже поднят vpn-tun.sh, только обновляет метку. Если порт 1080 занят, а pidfile пуст (чужой процесс) — не стартует (exit 1).
- `egress-watchdog.sh` — гасит туннель через `EGRESS_IDLE_SEC` (по умолчанию 60) бездействия через `vpn-tun.sh down 185` (по pidfile; НЕ `pkill -x sing-box` — тот убил бы и параллельный туннель 46); выходит, когда туннель погашен.
- `egress-down.sh` — ручная остановка туннеля и watchdog через `vpn-tun.sh down 185`.

Интеграция: перед вызовом mcp__exa__*/mcp__tavily__* или web_extract — запустить `egress-up.sh` (terminal). Watchdog сам погасит туннель через 60 сек. Прокси для запроса: `curl -x 127.0.0.1:1080` либо env `http_proxy/http...` (см. ниже).

**Pitfall 1 (env-прокси + проверка IP):** если `http_proxy` уже экспортирован, а туннель опущен — `curl` к любому хосту падает (порт не слушает). Поэтому `egress-up.sh` проверяет IP только через `--noproxy '*'`, иначе country получается пустым и скрипт ложно считает «не RU».

**Pitfall 2 (MCP + прокси):** Hermes MCP-инструменты (mcp__exa__*) подхватывают прокси только из окружения процесса — если Hermes запущен до export, MCP-клиент ходит напрямую и получает 403. Нужен ПОЛНЫЙ рестарт Hermes (выход + запуск `hermes`, не `/new` — `/new` не перечитывает env процесса). До рестарта — прямой MCP-вызов через curl (см. scripts/exa-mcp-direct.py).

**Pitfall 3 (pkill -f самоубийство):** `pkill -f "паттерн"` матчит ПОЛНУЮ командную строку — если твоя же команда содержит паттерн (напр. `pkill -f "egress-watchdog.sh"` внутри bash -c), процесс убивает сам себя (exit -15). Для остановки sing-box использовать `pkill -x sing-box` (точное имя процесса); watchdog запускать `setsid nohup`, а не pkill -f по собственному сценарию.

**Backend'ы web_extract Hermes** (`web.extract_backend`): exa / firecrawl / searxng / brave-free / tavily — каждому нужен свой ключ (EXA_API_KEY / FIRECRAWL_API_KEY / SEARXNG_URL / BRAVE_SEARCH_API_KEY / TAVILY_API_KEY). Все сидят за Cloudflare и банят RU IP одинаково (403 «Attention Required») — смена backend НЕ решает RU-блок, решает только прокси/туннель. Проверено 14.08.2026: и tavily, и exa дают 403 с RU IP, и оба — 200 через туннель 185.

## KES/DLP-что видно

- **WireGuard**: факт туннеля виден (UDP на нестандартный порт, сигнатуры handshake), KSC реплицирует события. Содержимое — нет (ChaCha20).
- **VLESS+Reality**: виден только TLS:443 к легитимному SNI. DPI не отличает от браузерного HTTPS. Содержимое — нет.
- DLP содержимое не читает в обоих случаях. Риск = факт нестандартного сетевого трафика на корпоративной машине.

## Скрипты

- `scripts/exa-mcp-direct.py` — прямой вызов web_search_exa через MCP-протокол поверх curl (обходит JA3-блок для urllib; работает когда mcp__exa__* не подхватились в сессию).
- `~/.hermes/scripts/egress-up.sh`, `egress-watchdog.sh`, `egress-down.sh` — on-demand туннель (подъём/авто-падение, см. секцию On-demand).

## References

- `references/ru-ip-cloudflare-block.md` — конкретика: блокировка казанского T2 Mobile IP, Googlebot-UA обход и его смерть, проверенные VPS.
