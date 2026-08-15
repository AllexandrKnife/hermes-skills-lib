# Real-World Investigation Examples

## Example: github-store.org

URL: `https://github-store.org/app?repo=rtk-ai/rtk`

### Initial suspicion
Domain `github-store.org` looks like a typosquat/imitation of `github.com`.
Referred to as a "store" which GitHub doesn't have.

### Investigation results

| Check | Finding |
|-------|---------|
| HTTP | 301 → same URL with trailing slash, then 200 HTML |
| Server | Cloudflare → Varnish → Fastly → origin |
| Server header | Cloudflare |
| WHOIS created | 2026-02-05 (3 months ago) |
| Registrar | NameCheap |
| DNS | Cloudflare NS, Cloudflare proxied A/AAAA |
| MX | 3 routes via Cloudflare Email Routing |
| TXT | None |
| Page title | "Opening in GitHub Store…" |
| Description | "Redirecting you to GitHub Store app to view this repository." |
| Login form | None (/login returns 404) |
| JS redirect | `githubstore://repo/{owner}/{name}` custom scheme (iOS/Desktop) or `intent://...` Android Intent with `package=zed.rainxch.githubstore` |
| GitHub cross-ref | `OpenHub-Store/GitHub-Store` — legitimate open-source project (14k ★, Kotlin, created 2025-11-21) |
| Referenced repo | `rtk-ai/rtk` — legitimate project (54k ★, Rust, CLI tool) |

### Classification
**Legitimate deep-link launcher** — not phishing. The domain acts as a web-to-native-app bridge for the GitHub Store Android/Desktop app. No credential harvesting, no malware delivery.

### Risk assessment
Low risk. The site only validates a `repo=owner/name` parameter and attempts to open a custom URI scheme. If the app isn't installed, it falls back to the project's GitHub releases page.

### Potential attack vectors (penetration testing interest)
1. **Deep link injection** — `repo` parameter unsanitized before insertion into custom scheme URI
2. **Custom scheme hijacking** — if malware registers `githubstore://` scheme first on a device
3. **No CSP** — page has no Content-Security-Policy header
4. **Domain brand confusion** — `github-store.org` could be used in social engineering to trick users
