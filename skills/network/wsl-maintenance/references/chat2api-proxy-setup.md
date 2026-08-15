# Chat2API + WSL Proxy Setup

## Overview
Chat2API (https://github.com/xiaoY233/Chat2API) is a cross-platform Electron app that turns AI web interfaces (DeepSeek, Kimi, GLM, Qwen, etc.) into OpenAI-compatible APIs. It runs as a desktop app on Windows and exposes an HTTP proxy on 127.0.0.1:8080.

This reference covers connecting WSL-based agent tools (Hermes Agent, Qwen Code) to Chat2API on Windows.

## Setup Flow

1. Install Chat2API on Windows (latest.exe from GitHub Releases)
2. Launch, add providers (DeepSeek, Kimi, GLM, etc.), get API tokens from web browsers
3. (Optional) Create API Key in Chat2API → API Keys
4. Start Proxy in Chat2API → Proxy Settings → Start Proxy
5. From WSL: check if it works → usually fails (see below)

## WSL Connectivity Fix

### Problem
Chat2API listens on `127.0.0.1:8080` on Windows. WSL2 localhostForwarding often fails with "Connection refused". Additionally, `localhostForwarding` in `/etc/wsl.conf` may be rejected on some WSL versions with `Unknown key 'network.localhostForwarding'`.

### Fix (Windows Admin PowerShell)
```powershell
# Step 1: Create portproxy
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=8080 connectaddress=127.0.0.1

# Step 2: Allow inbound connections through firewall
netsh advfirewall firewall add rule name="Chat2API" dir=in protocol=tcp localport=8080 action=allow

# Step 3 (if needed): Add app to Defender firewall exceptions
New-NetFirewallRule -DisplayName "Chat2API" -Direction Inbound -Action Allow -Program "$env:LOCALAPPDATA\Programs\chat2api\Chat2API.exe" -Protocol TCP -LocalPort 8080
```

### Cleanup (if port 8080 is stuck with svchost)
If netsh portproxy was deleted but port 8080 is still held by svchost.exe (PID shown by `netstat -ano | findstr :8080`), delete the proxy rule from admin PS and verify:
```powershell
netsh interface portproxy delete v4tov4 listenport=8080 listenaddress=0.0.0.0
```
After deletion, port 8080 should be free for Chat2API to claim. Check: `netstat -ano | findstr :8080`

### Verify
```powershell
# From WSL:
curl -s http://$(ip route show default | awk '{print $3}'):8080/v1/models -H "Authorization: Bearer <api-key>"
```

### Models Observed (May 2026)
- Kimi-K2.6, Kimi-K2.5 (Kimi provider)
- deepseek-v4-pro, deepseek-v4-pro-think, deepseek-v4-pro-search (DeepSeek provider)
- Plus others depending on configured providers

## Diagnostics: Is Chat2API Actually Working?

### Test 1: Model list (this is NOT sufficient)
```bash
curl -s http://$(ip route show default | awk '{print $3}'):8080/v1/models -H "Authorization: Bearer <key>"
```
✅ Succeeds even with expired provider tokens (model list is static from config).

### Test 2: Chat completion (the real test)
```bash
curl -s http://$(ip route show default | awk '{print $3}'):8080/v1/chat/completions \
  -H "Authorization: Bearer <key>" \
  -H "Content-Type: application/json" \
  -d '{"model":"DeepSeek-V3.2","messages":[{"role":"user","content":"Hi"}],"temperature":0.3,"max_tokens":50}'
```
This is the definitive test. Failures reveal provider token issues.

### Error Patterns

| Symptom | Likely Cause |
|---------|-------------|
| `curl → Connection refused` | localhostForwarding broken, or proxy not running |
| `curl → Empty reply from server` | Proxy process crashed but GUI alive. Kill all Chat2API processes and restart |
| `"Failed to acquire token: Authorization Failed"` | DeepSeek token expired |
| `"unauthenticated" / "REASON_INVALID_AUTH_TOKEN"` | Kimi JWT token expired |
| `"HTTP 401"` | GLM/Z.ai token expired |
| `"no chat ID returned"` | Qwen token expired or session issue |

**Common pattern:** Model list works → everything seems fine. But chat call fails → all provider tokens expired. The user needs to re-authenticate each provider in Chat2API GUI.

## Tradeoffs vs Direct API

| Factor | Chat2API (via WSL) | Direct DeepSeek API |
|--------|-------------------|-------------------|
| Stable address | ❌ IP changes after wsl --shutdown | ✅ api.deepseek.com |
| Speed | ~5-15s per request | ~1-3s |
| Frequency tolerance | Low (Web API rate limits, account ban risk) | High (paid API) |
| Cost | Free | Paid |
| Multi-model | ✅ One endpoint for all providers | ❌ One URL per provider |

## Decision: When to Use

- **Use Chat2API** for: one-off experiments, testing different models, lightweight queries
- **Use direct API** for: IDE integration, heavy coding sessions, autonomous agents making many sequential tool calls

## Hermes Agent Config (if needed)

```bash
WSL2_GW=$(ip route show default | awk '{print $3}')
hermes config set model.base_url "http://$WSL2_GW:8080/v1"
hermes config set model.api_key "sk-<your-key>"
hermes config set model.provider openai
hermes config set model.default "deepseek-v4-pro"
```

## Qwen Code Config (if needed)

Add to `modelProviders.openai` array in `~/.qwen/settings.json`:
```json
{
  "id": "chat2api",
  "name": "Chat2API Proxy",
  "description": "Chat2API on Windows (WSL bridge)",
  "envKey": "CHAT2API_KEY",
  "baseUrl": "http://172.29.112.1:8080/v1",
  "generationConfig": { "timeout": 120000, "maxRetries": 3 }
}
```
