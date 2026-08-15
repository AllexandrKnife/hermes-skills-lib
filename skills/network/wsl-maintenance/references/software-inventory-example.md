# Windows + WSL Software Inventory — Example Session (May 2026)

**Machine:** Lenovo laptop, Win 11, WSL2 Ubuntu 22.04  
**Disk:** C: 111 GB total, 103 GB used (93%), 8.6 GB free  
**User:** Пухаткин (8.3 short name: 0C7E~1)

## Windows Installed — Key Findings

### Biggest space hogs identified:

| Category | Examples | Est. savings | Status |
|----------|----------|-------------|--------|
| .NET workloads manifests (Android/iOS/MAUI/) | Multiple `Microsoft.NET.Sdk.*.Manifest-*` entries | **0 MB** — just 0.2 MB of manifest metadata, not actual packs | ⚠️ False alarm |
| WinSxS (Windows Component Store) | | 8,856 MB (8.6 GB) | Can reduce by 2-4 GB via DISM |
| AppData\Local (total) | Chrome, Yandex, Adobe, npm, VSCodium, Edge, Temp | **~21 GB** broadly | Multiple targets |
| Google Chrome | Full profile (cache+app) | 2,168 MB (2.2 GB) | Clean cache only |
| Yandex Browser | Full profile | 800 MB | Clean cache only |
| Adobe Acrobat (AppData\Local) | Cache + updater data | 1,840 MB (1.8 GB) | Remove with Acrobat |
| npm global | AppData\Local\npm (global packages) | 1,276 MB | Prune unused globals |
| npm-cache | AppData\Local\npm-cache | 357 MB | `npm cache clean --force` |
| VSCodium | .vscode-oss (extensions) | 478 MB | Prune unused extensions |
| Microsoft Edge | AppData\Local\Microsoft\Edge | 289 MB | Clean cache |
| User Temp | AppData\Local\Temp | 143 MB | Safe to delete |

### Adobe ARM (Adobe Update Manager cache) — 1,808 MB
This was the single biggest non-obvious space hog. The folder `%LOCALAPPDATA%\Adobe\ARM` contained two `.msp` files (Windows Installer patches) totaling 1.8 GB:
- `AcrobatDCx64Upd2500121223.msp` — 1,078 MB (Feb 2026)
- `AcrobatDCx64Upd2500120693.msp` — 730 MB (Sep 2025)

These are Adobe Acrobat update patches that were already applied. Adobe's updater (ARM) downloads and keeps them indefinitely. If the current Acrobat version is newer than these patches, they are stale and can be safely deleted without affecting Acrobat's operation.

**Lesson:** When auditing C: space, always check `%LOCALAPPDATA%\Adobe\ARM` for stale `.msp` files. The ARM folder is not cleaned by built-in tools (cleanmgr, Disk Cleanup, Storage Sense).

### Noteworthy:
- Two PowerShell 7 entries (old + new) — duplicate
- Visual C++ Debug Runtime 2019 (x64+x86) — not needed for production
- VSCodium, Far Manager 3, AmneziaWG, Git, Node.js — confirmed in use

### AppData Cache Deep-Dive

| Target | Size | Path (under %LOCALAPPDATA% or %APPDATA%) | Clean pattern |
|--------|------|------------------------------------------|--------------|
| Chrome Service Worker | ~500 MB | `..\Google\Chrome\User Data\Default\Service Worker\CacheStorage` | Delete contents — preserves logins |
| Chrome Cache+Code | ~700 MB | `..\Google\Chrome\User Data\Default\Cache`, `..\Code Cache` | May be absent in modern Chrome; SW cache is primary target |
| Yandex Browser | ~400 MB | `..\Yandex\YandexBrowser\User Data\Profile 3\Cache`, `..\Code Cache`, `..\Service Worker\CacheStorage` | Uses numbered profiles (Profile 3), not Default |
| Adobe Acrobat | 1,840 MB | `%LOCALAPPDATA%\Adobe` | Removed with Acrobat uninstall |
| npm global | 1,276 MB | `%LOCALAPPDATA%\npm` | `npm ls -g --depth=0` then remove unused |
| npm cache | 357 MB | `%LOCALAPPDATA%\npm-cache` | `npm cache clean --force` |

**Yandex Profile Detection:**
Get-ChildItem "$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data" -Directory
Look for "Profile 1", "Profile 2", "Profile 3" etc.

**WinSxS** on this machine: 8,856 MB (8.6 GB). Last DISM cleanup was recent — /ResetBase would not help much. If cleanup is stale, dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase (admin) can reclaim 2-4 GB.

## Windows Installed — Full Registry Listing (noise-filtered)

```
ADB AppControl
Adobe Acrobat (64-bit)
Adobe Refresh Manager
AmneziaWG
CPUID CPU-Z 2.18
DAEMON Tools Lite
Dolby Audio X2 Windows API SDK
Eclipse Temurin JDK with Hotspot 21.0.7+6 (x64)
Far Manager 3 (x86)
Git
Google Chrome
K-Lite Mega Codec Pack 16.1.0
Kingston SSD Manager
Lenovo System Update
MarketResearch
Microsoft Edge
Microsoft Office (Russian)
Microsoft OneDrive
Microsoft Update Health Tools
Microsoft Visual Basic for Applications 7.1 (x64)
NVIDIA Graphics Driver 466.27
NVIDIA PhysX
NVIDIA FrameView SDK
Node.js
Office 16 Click-to-Run components (x3)
Pandoc 3.8.3
PowerShell 7-x64
PowerShell 7.5.2.0-x64
Python 3.11.9 (multiple components)
Python 3.13.3 (multiple components)
Python Launcher
SPDS Extension for AutoCAD 2021
Scan To
VSCodium
Windows Subsystem for Linux
Windows Subsystem for Linux Update
WinRAR 5.71
Yandex (All Users)
```

## WSL Installed — Key Cleanup Candidates

| Package | Size | Reason |
|---------|------|--------|
| `libllvm15` | 114 MB | LLVM for Mesa — not needed without GPU |
| `libgl1-mesa-dri` | 32 MB | OpenGL — not needed in WSL |
| `mesa-va-drivers` + `mesa-vdpau-drivers` | 29 MB | Video acceleration — not needed |
| `libflite1` | 27.5 MB | TTS engine |
| `libmfx1` | 24.5 MB | Intel Media SDK |
| `libx265-199` | 16 MB | HEVC encoder |
| `libcodec2-1.0` | 15 MB | Codec2 |
| `gcc-arm-linux-gnueabihf*` + cross deps | ~110 MB | ARM cross-compiler |
| GTK3 / X11 / alsa / pulse / fonts | ~300 MB | GUI stack |
| `pocketsphinx-en-us` | 37 MB | Speech recognition |
| `cloud-init` + `landscape*` + `ubuntu-pro*` + `apport*` | ~20 MB | Cloud/VPS bloat |

## Extraction Commands Used

```bash
# WSL package inventory
dpkg-query -W -f='${Package}\t${Version}\t${Section}\t${Installed-Size}\n' | sort

# WSL manually installed
apt-mark showmanual | sort

# Windows software inventory — write PS1 to %TEMP%, execute via pwsh.exe -File
# (see scripts/win-software-audit.ps1 for reusable script)
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\0C7E~1\AppData\Local\Temp\win-software-audit.ps1"
```
