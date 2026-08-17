# Cloudflare-блокировка RU-IP и проверенные обходы (2026-08-01)

## Исходная проблема

Казанский мобильный IP `94.77.12.35` (AS48092 T2 Mobile LLC, CGNAT-пул) блокируется
Cloudflare для всех API-эндпоинтов Exa:
- `https://mcp.exa.ai/mcp` → 403 «Attention Required!» (server: cloudflare)
- `https://api.exa.ai/search` → 403
- `https://exa.ai` → 200 (сайт не блокируется, только API-хосты)

Симптомы: `curl` POST на mcp.exa.ai отдаёт HTML-страницу CF с «Sorry, you have been blocked»,
Ray ID в ответе, `Your IP` = казанский.

## Googlebot-UA — временный обход, умирает через часы

Сначала сработал обход через заголовок:
```
User-Agent: Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)
```
— `curl` POST с этим UA давал 200 с того же казанского IP, даже GET возвращал 405
(значит, CF пропускал), а не 403. Добавили в конфиг Hermes MCP `headers.User-Agent`.

Через ~1 час тот же IP + тот же Googlebot-UA → снова 403. Cloudflare ужесточил WAF
(IP попал в репутационный список или правило обновили). Вывод: Googlebot-UA — не решение,
только отсрочка. Рабочее решение — смена выходного IP (VPN/туннель).

## JA3-фингерпринт: urllib 403, curl 200

С амстердамского/франкфуртского IP (туннель) `curl` проходит 200, а Python
`urllib.request.urlopen` получает 403 — Cloudflare режет по TLS-отпечатку клиента.
Решение: прямой MCP-вызов через `subprocess.run(["curl", ...])` (см. scripts/exa-mcp-direct.py).

## Jina AI Reader (r.jina.ai): 451 с RU-IP, 200 с VPS (2026-08-02)

Проверено в сессии: `r.jina.ai` (бесплатный рендер-прокси для статей) возвращает
**451 "Unavailable For Legal Reasons" на любой URL** с российского IP — включая корень
сервиса, example.com, habr.com, dzen.ru. С VPS 45.134.15.185 (Frankfurt) — 200 и полный
текст статьи. Сервис блокирует РФ-адреса целиком, не по URL.

Обход: гнать запрос через туннель/прокси:
```bash
curl -x http://127.0.0.1:1080 -sL "https://r.jina.ai/http://<url>"   # после vpn-tun.sh up 185
# либо SSH-прокси на VPS
```
Проверка статуса перед использованием: `curl -s -o /dev/null -w "%{http_code}" https://r.jina.ai/`
(200 = ок, 451 = нужен туннель). Это отдельный блок от Cloudflare-403 — Jina отвечает 451
(legal reasons), не 403, но лечится тем же инструментом (смена egress-IP).

## Проверенные выходные IP

| IP | Локация | Exa MCP | Jina r.jina.ai |
|---|---|---|---|
| 94.77.12.35 | Казань, T2 Mobile (без VPN) | 403, заблокирован | — (ожидается 451) |
| 45.134.15.185 | Франкфурт, First Server (VPS sing-box) | 200 | 200 |
| 46.30.47.120 | Амстердам, Iron Hosting (VPS WireGuard) | 200 | — (не проверялся) |

Оба VPS-выхода работают; для корпоративной машины с KES предпочтителен sing-box
VLESS+Reality (маскировка под TLS к apple.com) — см. SKILL.md.

## Ключи/параметры для проверки (не критичны, переснимаются с сервера)

VLESS+Reality на 45.134.15.185: порт 39261, SNI apple.com, short_id f77680e3,
публичный ключ Reality: `ryADwFj6VRw2B9jL2Ubs8q0oIZVbngIB6ErCCwk3djw`.
WireGuard на 46.30.47.120: wg0:54711, подсеть 10.77.77.0/24, публичный ключ сервера
`SqQsxjdGLKHt2+VpVIt2OJCWeUKs1jzTvz1OEVr+aDo=`, свободные пиры .6/.7/.8.
SSH: root / пароль VPS_ROOT_PASSWORD_PLACEHOLDER на всех VPS (см. references/vps-inventory.md в vps-adguard-dns-integration).
