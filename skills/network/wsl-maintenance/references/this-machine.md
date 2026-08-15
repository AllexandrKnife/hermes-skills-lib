# This Machine: WSL Environment Specifics

## Hardware
- CPU: Intel Core i3-6006U (2 cores, 2 threads)
- RAM: 4GB total (WSL gets ~2-4GB depending on .wslconfig)
- Disk: 1TB HDD
- OS: Ubuntu 22.04 on WSL2
- Windows version: 10.0.19045.5854 (Windows 10 22H2)

## Disk (updated 2026-06-09)

### C: Drive — 104.3 GB used, 6.5 GB free (5.8%, critical)

Top space hogs (measured 2026-06-09):
| Location | Size | Notes |
|----------|------|-------|
| **WSL VHDX** (`AppData\Local\wsl\{UUID}\ext4.vhdx`) | 12.5 GB | WSL2 virtual disk (#1 hog, needs compact) |
| `Windows\Installer` | 13.5 GB | MSI cache, DISM doesn't clean this |
| `AppData\Local` (user) | 27.7 GB | See breakdown below |
| `Windows\WinSxS` | timed out | last DISM cleanup: ~May 2026 |
| `Program Files` | 11.2 GB | |
| `Program Files (x86)` | 5.5 GB | |
| `TCPU75` | 2.3 GB | unknown folder at C:\ |
| `ProgramData` | 0.7 GB | |
| `DriverStore` | 2.7 GB | old drivers |

### AppData\Local breakdown (27.7 GB total, measured 2026-06-09)
- `wsl` (VHDX): 12.5 GB
- `Google`: 2.0 GB
- `Programs`: 1.7 GB
- `Yandex`: 1.4 GB
- `Microsoft`: 1.1 GB
- `ms-playwright`: 0.7 GB
- `npm-cache`: 0.5 GB
- `NVIDIA Corporation`: 0.4 GB
- `Apple Computer`: 0.4 GB
- `Temp`: 0.3 GB
- Others: ~0.8 GB

### WSL /home/user breakdown (5.4 GB after cleanup, measured 2026-06-09)
| Path | Size | Status |
|------|------|--------|
| `.hermes` | 3.5 GB | Hermes Agent (node_modules, bins) |
| `.bun` | 432 MB | JS runtime, hosts gbrain CLI |
| `.nvm` | 321 MB | Node.js v26.3.0 |
| `.local` | 235 MB | Python/pip installs |
| `.npm` | 165 MB | |
| `.gbrain` | 43 MB | |
| `.qwen` | 17 MB | |
| `.kimi-webbridge` | 9.6 MB | |

### Cleanup done 2026-06-09
| Step | Action | Result |
|------|--------|--------|
| 1 | `cleanmgr /sagerun:1` | ~0.1 GB freed (minimal) |
| 2 | `DISM /StartComponentCleanup` | ~0 GB (already run recently) |
| 3 | `scoop cache rm` | 0 GB (already empty) |
| 4 | `npm cache clean --force` + `pip cache purge` | 6 files |
| 5 | WSL internal cleanup: `~/.cache/camoufox/` (1.4 GB), `~/.cache/electron/` (110 MB), `~/.cache/uv/` (74 MB), `~/.cache/node-gyp/` (65 MB), `.npm/` (165 MB), `.mp4.part` files (53 MB) | ~1.5 GB freed inside WSL |
| **Pending** | VHDX compact (wsl --shutdown + diskpart) | expected ~7 GB on C: |

Top space hogs (measured 2026-06-09):
| Location | Size | Notes |
|----------|------|-------|
| **WSL VHDX** (`AppData\Local\wsl`) | 12.5 GB | #1 hog, dynamic VHDX — needs compact |
| `AppData\Local` (user) | 27.7 GB | see breakdown below |
| `Windows\Installer` | 13.5 GB | MSI cache, DISM doesn't clean this |
| `Program Files` | 11.2 GB | |
| `Program Files (x86)` | 5.5 GB | |
| `DriverStore` | 2.7 GB | old drivers |
| `TCPU75` | 2.3 GB | unknown folder at C:\ |
| `ProgramData` | 0.7 GB | |

### AppData\Local breakdown (27.7 GB total, 2026-06-09)
- `wsl` (VHDX): 12.5 GB
- `Google`: 2.0 GB
- `Programs`: 1.7 GB
- `Yandex`: 1.4 GB
- `Microsoft`: 1.1 GB
- `ms-playwright`: 0.7 GB
- `npm-cache`: 0.5 GB
- `NVIDIA Corporation`: 0.4 GB
- `Apple Computer`: 0.4 GB
- `Temp`: 0.3 GB
- Others: ~0.8 GB

### Cleanup done 2026-06-09 — freed 1.5 GB inside WSL
| Step | Action | Result |
|------|--------|--------|
| 1 | `cleanmgr /sagerun:1` | ~0.1 GB |
| 2 | `DISM /StartComponentCleanup` | ~0 GB (already run recently) |
| 3 | `scoop cache rm` | 0 GB |
| 4 | `npm cache clean --force` + `pip cache purge` | 6 files |
| 5 | WSL: `~/.cache/camoufox/` (1.4 GB), `electron` (110 MB), `uv` (74 MB), `node-gyp` (65 MB), `.npm/` (165 MB), `.mp4.part` (53 MB) | ~1.5 GB inside WSL |
| **Pending** | VHDX compact (wsl --shutdown + diskpart) | expected ~7 GB on C: |

## C: Cleanup Workflow Guidelines

When asked to clean C: drive:

1. **Check available space first**: use `pwsh.exe -File C:\\Users\\0C7E~1\\AppData\\Local\\Temp\\freespace.ps1`
2. **Analyze with targeted PS1 scripts** (not WSL `du` on /mnt/c/ — too slow)
3. **Follow this order**: user temp → npm/pip caches → browser caches → DISM analysis → DISM cleanup → WSL internal caches → VHDX compact
4. **Nonelevated first**: temp/caches can be cleaned without admin rights
5. **DISM is usually already clean** on this machine (last cleanup ~May 2026)
6. **Biggest remaining target**: WSL VHDX compact (5-8 GB potentially) — requires wsl --shutdown
7. **Key discovery path for VHDX**: `$env:LOCALAPPDATA\wsl\{UUID}\ext4.vhdx` — on this machine the VHDX is NOT in the old `lxss\` path nor under `Packages\Canonical...`, but under `Packages\MicrosoftCorporationII.WindowsSubsystemForLinux_8wekyb3d8bbwe\LocalState`. Use `Get-ChildItem "$env:LOCALAPPDATA\wsl" -Recurse -Filter "*.vhdx"` to find it.

## Installed Tools
- jq, fzf, fd-find (as fdfind), neovim (0.6.1), gh (2.4.0)
- git, tmux, htop, ripgrep, yt-dlp, ffmpeg
- Qwen Code CLI v0.15.6 (Windows npm global, WSL interop)
- Hermes Agent (Nous Research)

## Shell
- bash (default), user 'user', no passwordless sudo
- sudo password: 1qsxdrgb
- Cyryllic Windows username: Пухаткин → 8.3 short name: 0C7E~1

## WSL Config
```ini
[boot]
systemd=true
[user]
default=user
[network]
localhostForwarding = true
```

## Networking
- WSL2 gateway: 172.29.112.1 (Windows host IP, changes after wsl --shutdown)
- Windows hostname: DESKTOP-AVK4BJ6

## Known Quirks
- Windows npm binaries accessible from WSL PATH but slow (9P interop)
- PowerShell piped from WSL has silent failures with ForEach-Object and complex scripts → use -File with C:\Windows\Temp\ instead
- CMD.EXE from WSL emits UNC path warnings but commands still work
- localhostForwarding is unreliable — WSL apps hitting localhost:XXXX on Windows may get "Connection refused"
- DNS resolution of Windows hostname from WSL is not always reliable
- **pwsh.exe** preferred over cmd.exe or powershell.exe from WSL — handles UNC CWD correctly

## C: Disk Analysis Pattern (from WSL)
```powershell
# Write PS1 to user %TEMP%, execute via pwsh.exe -ExecutionPolicy Bypass -File
# Always use 8.3 short name (0C7E~1) for Пухаткин
# Prefer file-based execution over piped scripts
```

## Chat2API on Windows (May 2026)
- Installed on Windows, serves OpenAI-compatible API on 127.0.0.1:8080
- API key: sk-0aRNYf5dFhleJqmhUkpan7oCnqyRuK5KB3IngxX1ML85DMEJ
- Providers configured: DeepSeek, Kimi (and possibly others)
- Access from WSL requires netsh portproxy + firewall rule (see references/chat2api-proxy-setup.md)

## Router (Keenetic 4G KN-1210)
- IP: 192.168.1.1, admin/1qsxdrgb
- Firmware: NDMS 3.07.C.5.0-0
- 3 WireGuard tunnels: MyNL (10.77.77.14), MSK (10.77.88.4), GeR (10.8.1.3)

## VPS MyNL
- IP: 46.30.47.120, Debian 12, root/1qsxdrgb
- WireGuard wg0: 10.77.77.1/24, 14 peers
- 1 vCPU, 457MB RAM, 9.8GB disk (3.8GB free)
