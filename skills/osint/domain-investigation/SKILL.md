---
name: domain-investigation
description: "Use when Systematic reconnaissance of web domains and"
critic_status: done
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [reconnaissance, osint, phishing, domain-analysis, dns, security]
    related_skills: [security-audit, godmode, spike]
prerequisites:
  commands: [curl, dig, whois, python3]
  notes: "whois — apt install whois; без него использовать RDAP fallback (rdap.org) из раздела 1."
---

# Domain Investigation

Systematic reconnaissance of a web domain or URL to determine its ownership, infrastructure, intent, and security posture. Use this when the user shares an unknown URL, suspects phishing, or asks you to evaluate a website's legitimacy before interacting with it.

## When to Use

- User shares a link and asks "what is this?" or "is this safe?"
- Domain looks suspicious or impersonates a known brand (`github-store.org`, `go0gle.com`, etc.)
- User asks you to assess a third-party service before using it
- Investigating a callback URL, webhook, or OAuth redirect target
- Any URL with an unfamiliar TLD or lookalike domain name pattern
- User is doing penetration testing or OSINT research and needs a structured methodology

**Do NOT use for** code review of a known legitimate project — use `security-audit` instead.

## Methodology — 7 Dimensions

Work through these in order. Every dimension matters — skipping one creates blind spots.

### 1. Domain Ownership & Registration

```bash
# Registration date, registrar, expiry
# whois (если установлен: apt install whois) либо RDAP без пакета:
whois <domain> 2>/dev/null || curl -s "https://rdap.org/domain/<domain>" | python3 -m json.tool

# DNS records
dig +short <domain> A AAAA
dig +short www.<domain> A AAAA
dig +short <domain> MX
dig +short <domain> TXT
dig +short <domain> CNAME
dig +short <domain> NS

# Check if it's a subdomain of a known service (GitHub Pages, Cloudflare, etc.)
host <domain>
```

**What to look for:**
- **Recently registered domains** (< 6 months) are higher risk — especially for brand impersonation
- **NameCheap + Cloudflare** combo is common for disposable/phishing infrastructure
- **Registrant privacy** (REDACTED/GDPR) is common but the registrar and date still matter
- **CNAME to github.io** = GitHub Pages (usually legitimate)
- **Cloudflare proxied** (A records are Cloudflare IPs) — the real origin is hidden
- **Google Workspace TXT** records (google-site-verification, google-gws-recovery) = legitimate business use
- **Missing MX** = no email — rarely a sign of legitimacy by itself but notable

### 2. HTTP Profile & Infrastructure

```bash
# Full response headers
curl -sI --max-time 10 "https://<domain>/"

# Follow redirect chain
curl -sL --max-time 15 -D - "https://<domain>/" -o /dev/null

# Check sub-paths
for path in /login /admin /api /health /callback /webhook /oauth /auth; do
  curl -sI --max-time 5 "https://<domain>$path" | head -1
done
```

**What to look for:**
- **Server header**: `GitHub.com` = GitHub Pages, `cloudflare` = proxied, `nginx`/`Caddy`/`Apache` = dedicated server
- **Redirect chain**: 301 → www is normal. Multi-hop redirects (→ 302 → 301) are suspicious
- **X-GitHub-Request-Id**, **X-Served-By (varnish)**, **X-Cache (Fastly)** — indicates GitHub Pages infrastructure
- **Missing security headers**: no CSP, no HSTS, no X-Frame-Options is a yellow flag
- **Login/OAuth endpoints**: 200 means credential harvesting is possible. 404 means no login page (good sign for a tool site)
- **`cf-cache-status: DYNAMIC`** = Cloudflare proxied

#### Infrastructure Fingerprinting (CDN / Cache Detection)

Three common caching/CDN layers appear in headers. Recognize them to locate the origin:

| Layer | Header Pattern | Meaning |
|-------|---------------|---------|
| **Cloudflare** | `cf-ray`, `server: cloudflare`, `cf-cache-status` | Reverse proxy; real origin hidden |
| **Varnish** | `x-varnish`, `x-served-by`, `via: 1.1 varnish` | Cache layer (often behind GitHub Pages) |
| **Fastly** | `x-fastly-request-id`, `x-timer`, `via: 1.1 fastly` | Edge cache |
| **GitHub Pages** | `server: GitHub.com`, `x-github-request-id` | Static hosting on GitHub infra |

A chain like `Cloudflare → Varnish → Fastly → origin` means the server header may report only the outermost layer (e.g. `cloudflare`). Look past it using the inner layer headers.

### 3. Page Content & Branding

**⚠️ JS-rendered platforms (Dzen, Habr, VC.ru):** These sites (especially Dzen) redirect standard curl to SSO login. Use Googlebot UA (`-H "User-Agent: Googlebot/2.1 (+http://www.google.com/bot.html)"`) to bypass. Then strip `<script>`/`<style>` tags and extract text nodes via regex. See `references/fact-checking-methodology.md` for the full Dzen extraction recipe and credibility assessment framework.

**Social media URLs (Instagram, YouTube):** These JS-heavy platforms embed full post content in OpenGraph meta tags (`og:title`, `og:description`, `og:image`). Extract post text, author, date, likes, and image without rendering JS. See `references/social-media-extraction.md` for platform-specific recipes.

```bash
curl -sL --max-time 15 "https://www.instagram.com/p/SHORTCODE/" | python3 -c '
import sys, re
html = sys.stdin.read()
for prop in ["og:title", "og:description", "og:image"]:
    m = re.search(f"<meta property=\"{prop}\" content=\"([^\"]+)\"", html)
    if m: print(f"{prop}: {m.group(1)}")
'
```

```bash
curl -sL --max-time 15 \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
  "https://<domain>/" | python3 -c "
import sys, re
html = sys.stdin.read()
# Remove scripts and styles
cleaned = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL)
cleaned = re.sub(r'<style[^>]*>.*?</style>', '', cleaned, flags=re.DOTALL)
cleaned = re.sub(r'<[^>]+>', '\n', cleaned)
lines = [l.strip() for l in cleaned.split('\n') if l.strip()]
print('\n'.join(lines[:80]))
"
```

**What to look for:**
- **Favicon / app icon** — does it reference some other domain? (e.g. `raw.githubusercontent.com/...`)
- **Title tag**: does the page title match the domain name?
- **OpenGraph tags** (`og:title`, `og:description`) — planted social proof
- **Language**: is it in the same language the user expects?
- **Copied branding**: logos, color schemes, font imports (Google Fonts link reveals design intent)
- **robots.txt**: `noindex,nofollow` on a legitimate landing page is unusual

### 4. JavaScript & Redirect Logic

This is the most critical step for phishing assessment:

```python
import sys, re
html = sys.stdin.read()
scripts = re.findall(r'<script[^>]*>(.*?)</script>', html, re.DOTALL)
links = re.findall(r'href=[\"\\']([^\"\\']+)[\"\\']', html)
for i, s in enumerate(scripts):
    if s.strip():
        print(f'--- Script {i} ---')
        print(s[:3000])
```

**What to look for:**
- **Custom URI schemes** (`githubstore://`, `myapp://`, `customscheme://`) — used to open native apps. Usually legitimate if the app is real, but can be hijacked
- **Android Intent URIs** (`intent://...#Intent;...;end`) — can auto-launch apps on Android
- **`window.location.replace()`** with a timeout — auto-redirect to a custom scheme or external URL
- **Hidden form submission** — credential harvesting
- **Fallback URL** in Intent URI — where the user goes if no app is installed
- **Deep link injection** — is user input (query params) embedded unsanitized into the URI?
- **Console logging** — reveals developer intent and debugging mindset

### 5. GitHub & Social Proof Verification

```bash
# If the page references a GitHub repo
curl -sL --max-time 10 \
  "https://api.github.com/repos/<owner>/<repo>" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if 'message' in d:
    print(f'API Error: {d[\"message\"]}')
else:
    print(f'Stars: {d.get(\"stargazers_count\")}')
    print(f'Description: {d.get(\"description\")}')
    print(f'Created: {d.get(\"created_at\")}')
    print(f'Archived: {d.get(\"archived\")}')
    print(f'Topics: {d.get(\"topics\")}')
    print(f'Default branch: {d.get(\"default_branch\")}')
"
```

**What to look for:**
- **Does the GitHub repo actually exist?** — 404 API response means the reference is fabricated
- **Star count** — high stars + recent creation date is a pattern that can be gamed
- **Archived** — real but abandoned
- **Topics** — do they match the page's claims?
- **Cross-reference the page's GitHub org** with the domain: does the org have other credible repos?
- **Repo contents** — check for actual source code, not just a README

### 6. Security Posture Assessment

Check headers and configuration:

```bash
curl -sI --max-time 10 "https://<domain>/" | grep -iE 'x-frame-options|content-security-policy|strict-transport|referrer-policy|x-content-type|x-xss-protection|permissions-policy'
```

**What to look for:**
- **No CSP** — means the page can load arbitrary scripts. If JS is dynamic, XSS is possible
- **X-Frame-Options: SAMEORIGIN** — clickjacking protection within the domain, but not cross-domain
- **HSTS** — present is good, missing is a downgrade risk
- **Permissions-Policy** — `camera=(), microphone=(), geolocation=()` is a good sign
- **Referrer-Policy: same-origin** — good privacy posture

### 7. Cross-referencing & Context

Don't evaluate a domain in isolation. Cross-reference:

1. **Related domains**: does the same org own other domains? (`rtk-ai.app`, `rtk.ai`, `getrtk.com`)
2. **Project → Domain → Repository** chain: is the repository mentioned on the page actually the owner of the domain?
3. **Discord/Social links**: do they point to real communities?
4. **Infrastructure match**: does the hosting infrastructure match what you'd expect for the claimed project type?

## Quick Classification Guide

After completing the 7 dimensions, classify the domain into one of these categories for a rapid verdict:

| Category | Characteristics | Action |
|----------|----------------|---------|
| **Legitimate** | Real project, proper infra, no login prompts, verified via GitHub API | Safe to visit |
| **Phishing** | Login forms, recent domain, typosquatting, credential exfiltration | Block, report |
| **Deep link launcher** | Custom schemes, no login, no data collection, just redirects to native app | Low risk |
| **Scam / malware** | Promises downloads, binaries, "cracked" software | Block |
| **Parked / under construction** | Minimal content, no functional pages | Not actionable |

**Вердикт по сходимости (приём 16):** «legitimate» требует согласованных сигналов минимум из 2-3 измерений (инфраструктура + GitHub + контент). Один сильный сигнал (существующий repo / приличный UI) — НЕ вердикт, а заявка на проверку (pitfalls: fancy UI ≠ legitimate, звёзды геймятся). Вердикт «phishing» тоже по 2+ признакам, не по одному (свежий домен сам по себе — scrutiny, не приговор).

**Стоп-критерий (форсирование, пористость):** явные фишинговые признаки в первых 2-3 измерениях (свежий домен + login-форма + отсутствие инфраструктуры) → вердикт phishing БЕЗ прогона оставшихся измерений; оставшиеся — только как evidence для отчёта. Не тратить время на полный цикл, когда вердикт уже очевиден.

## Report Template

Use this structure for the final summary:

```
## Summary

**<domain>** — [legitimate/suspicious/malicious]. [One-sentence verdict.]

## Evidence

| Dimension | Finding |
|---|---|
| Registration | [registrar, date, privacy status] |
| DNS | [A/AAAA/CNAME/MX/TXT summary] |
| HTTP | [server, redirects, security headers] |
| Content | [page description, branding, JS behavior] |
| GitHub | [repo exists? stars, activity] |
| Security | [CSP, HSTS, XFO assessment] |

## Attack Vectors

- Bullet list of specific exploitable weaknesses found
- e.g. Deep link injection via unsanitized query param
- e.g. No CSP allows arbitrary script injection
- e.g. Custom URI scheme can be hijacked by a malicious app

## Verdict

[Clear statement: safe to visit / phishing / mixed / unknown]
```

## Pitfalls

- **Fancy UI ≠ legitimate**. Phishing pages often have better CSS than real ones. Material You design, animations, gradients — all trivially copied.
- **High GitHub stars can be gamed**. Check the created date, commit history, and actual source code.
- **"It's just a redirect page"** — the redirect target (custom URI scheme, Intent URI) is the actual attack surface. Analyze it.
- **Cloudflare hides the origin**. You can't tell if the backend is legitimate or compromised. Focus on what's visible (headers, JS, content).
- **New TLDs (.app, .dev, .store) are not inherently suspicious**, but they require stronger evidence of legitimacy.
- **Open-source ≠ secure**. A 14k-star open-source project can still be used by a separate phishing domain that references it for credibility.
- **Wait for WHOIS rate limiting**. Some registrars rate-limit. If `whois` hangs, use dig + curl analysis instead.
- **Don't visit interactive pages**. Use curl with `--max-time` and never run obfuscated JavaScript. Extract and read it statically.
- **Don't execute downloaded binaries or scripts** from untrusted domains during investigation.
- **Custom URI schemes** (`myapp://`) are normal for native apps, but can be hijacked by malware that registers the same scheme first.
- **New domain ≠ malicious** — but a domain registered <3 months ago for an established project name warrants scrutiny.
- **WHOIS privacy (REDACTED/GDPR)** is not a red flag by itself — many legitimate domains use privacy shielding.
- **Some legitimate projects use non-standard domains** — always cross-reference with GitHub API before dismissing a lookalike.

## See Also

- `security-audit` — for code-level vulnerability analysis of a repository
- `spike` — for one-off experiments to test a hypothesis about a domain
- `godmode` — for red-teaming scenarios involving model behavior analysis

## Reference Files

- `references/session-example.md` — full worked example (github-store.org + RTK plugin discovery)
- `references/real-examples.md` — condensed real-world investigation example with threat assessment
- `references/fact-checking-methodology.md` — extracting text from JS-heavy Russian platforms (Dzen, Habr) + structured credibility assessment framework for online articles
- `references/social-media-extraction.md` — extracting post content from Instagram/YouTube/Twitter via OpenGraph tags without authentication
