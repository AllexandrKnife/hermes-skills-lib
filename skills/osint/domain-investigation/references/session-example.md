# Domain Investigation — Worked Example

Full investigation of `github-store.org`, `rtk-ai.app`, and the RTK Hermes Agent plugin. Demonstrates the 7-dimension methodology.

## Scenario

User shared link: `https://github-store.org/app?repo=rtk-ai/rtk`
Follow-up link: `https://www.rtk-ai.app/`
Question: Is github-store.org phishing? Can RTK (Rust Token Killer) save tokens for Hermes Agent?

## Step-by-step

### 1. Domain Ownership & Registration

**github-store.org:**
```
Registrar: NameCheap
Created: 2026-02-05 (3 months ago)
DNS: Cloudflare (roxy.ns.cloudflare.com, tosana.ns.cloudflare.com)
A: 2606:4700:3035::ac43:8861, 2606:4700:3032::6815:3648 (Cloudflare proxied)
MX: route1-3.mx.cloudflare.net (Cloudflare Email Routing)
```

**rtk-ai.app:**
```
A: CNAME → rtk-ai.github.io → GitHub Pages IPs (185.199.108.153, etc.)
TXT: google-site-verification=..., google-gws-recovery-domain-verification=...
www → 301 → non-www (actually www is canonical)
```

**Takeaway:** github-store.org uses NameCheap + Cloudflare (common for new projects). rtk-ai.app is GitHub Pages with Google Workspace — legitimate infrastructure.

### 2. HTTP Profile

**github-store.org:**
```
→ 301 /app → /app/?repo=... (trailing slash)
→ 200
Server: cloudflare
X-GitHub-Request-Id: present (GitHub Pages behind proxy)
X-Served-By: varnish (Fastly)
/login: 404
```

**rtk-ai.app:**
```
→ 301 rtk-ai.app → www.rtk-ai.app
→ 200
Server: GitHub.com
Content-Length: 147,529 (marketing site)
```

### 3. Page Content

**github-store.org:**
- Material You design (teal seed), dark/light theme
- Favicon: `raw.githubusercontent.com/OpenHub-Store/GitHub-Store/.../app_icon.png`
- Title: "Opening in GitHub Store…"
- Description: "Redirecting you to GitHub Store app to view this repository."
- OpenGraph: references OpenHub-Store on GitHub
- Google Fonts: Outfit font
- No login form, no credential prompts

**rtk-ai.app:**
- Marketing site for RTK (Rust Token Killer)
- Hero: "Your AI agent is drowning in CLI noise. Fix it."
- Stats: 89% avg noise reduction, 3x longer sessions, 54.3k stars
- Language switcher: EN, FR, ES, DE, ZH, JA
- Links to Discord, GitHub, Support

### 4. JavaScript

**github-store.org — single inline script:**

```javascript
const params = new URLSearchParams(window.location.search);
const repo = params.get('repo');

// Validate: must be owner/name format
const match = repo ? repo.match(/^([^/]+)\/([^/]+)$/) : null;

const customSchemeUri = 'githubstore://repo/' + owner + '/' + repoName;
const intentUri = 'intent://repo/' + owner + '/' + repoName
    + '#Intent;scheme=githubstore;package=zed.rainxch.githubstore;'
    + 'S.browser_fallback_url=' + encodeURIComponent(
        'https://github.com/OpenHub-Store/GitHub-Store/releases/latest')
    + ';end';

// Android → Intent URI; iOS/Desktop → custom scheme
const openUri = isAndroid ? intentUri : customSchemeUri;

// Auto-redirect after 1.2s (non-Android)
if (!isAndroid) {
    setTimeout(() => window.location.replace(openUri), 1200);
}
```

**Analysis:** The JS validates the `repo` param (owner/name format), constructs a deep link, and auto-redirects. No credential harvesting, no obfuscation, no hidden forms. The Android Intent locks to package `zed.rainxch.githubstore` which prevents scheme hijacking.

**Potential attack vector:** The `repo` value is interpolated into the URI without encoding — but the regex restricts it to `owner/name` format. No XSS vector from the query param.

### 5. GitHub Verification

**OpenHub-Store/GitHub-Store:**
```
Stars: 14,004
Description: A free, open-source app store for GitHub releases
Language: Kotlin (Compose Multiplatform)
Created: 2025-11-21
Archived: false
Topics: android, desktop, kotlin, open-source, github-store, ...
```

**rtk-ai/rtk:**
```
Stars: 54,370
Description: CLI proxy that reduces LLM token consumption by 60-90%
Language: Rust
Created: 2026-01-22
HTML: https://github.com/rtk-ai/rtk
Default branch: develop
```

**Cross-reference:** The favicon and OG image on github-store.org link directly to OpenHub-Store's repo. The repo is active (not archived), has real code (Kotlin/Compose), and the star count is consistent with an established project. No fabrication.

### 6. Security Posture

**github-store.org:**
- X-Frame-Options: SAMEORIGIN
- Strict-Transport-Security: max-age=31536000; preload
- Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()
- X-Content-Type-Options: nosniff
- X-XSS-Protection: 1; mode=block
- **NO Content-Security-Policy** — notable gap
- Referrer-Policy: same-origin

**rtk-ai.app:**
- Standard GitHub Pages headers
- HSTS: max-age=31556952
- No custom CSP

### 7. Cross-referencing

The chain connects:
```
github-store.org  →  OpenHub-Store/GitHub-Store (14k★ Kotlin app)
                        ↓ (deep link to)
rtk-ai/rtk  →  www.rtk-ai.app (official marketing site, GitHub Pages)
```

Both projects are real, the domains match their respective projects, and the infrastructure (Cloudflare + GitHub Pages) is consistent with a legitimate open-source ecosystem.

## RTK Hermes Plugin Discovery

This session also discovered that RTK has a **native Hermes Agent plugin**:

**Location:** `github.com/rtk-ai/rtk/blob/develop/hooks/hermes/rtk-rewrite/`

**Files:**
- `plugin.yaml` — declares `pre_tool_call` hook
- `__init__.py` — bridges terminal commands through `rtk rewrite`

**How it works:**
1. Hook registers `pre_tool_call` callback
2. When `tool_name == "terminal"` and `args["command"]` is a string:
   - Runs `rtk rewrite <command>` (2-second timeout, fails open)
   - Exit 0/3: rewrites `args["command"]` to the RTK-prefixed version
   - Exit 1/2: passes through unchanged
3. Fails open — missing RTK binary, timeout, or error → original command runs

**Installation:**
```bash
cargo install --git https://github.com/rtk-ai/rtk
rtk init --agent hermes
```
Plugin lands at `~/.hermes/plugins/rtk-rewrite/`

**Coverage:** Python3, git, cargo, grep, ls, cat, docker, pytest, and 95+ other commands
