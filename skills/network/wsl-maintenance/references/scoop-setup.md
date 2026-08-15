# Scoop (Windows Package Manager) — Setup & Repair from WSL

## Installation

```powershell
pwsh.exe -NoProfile -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; irm get.scoop.sh | iex"
```

- Scoop installs to `C:\Users\<user>\scoop\apps\scoop\current\`
- Shims go to `C:\Users\<user>\scoop\shims\` — add to **user PATH** via:
  ```powershell
  $env:USERPROFILE\scoop\shims
  ```
  Set via `[Environment]::SetEnvironmentVariable('Path', $userPath + ';' + $shims, 'User')`

## Invoking Scoop from WSL

Direct `scoop` command won't work from WSL (different PATH namespace). Use the scoop.ps1 script directly:

```powershell
pwsh.exe -NoProfile -Command "& 'C:\Users\<user>\scoop\apps\scoop\current\bin\scoop.ps1' <command>"
```

Or if PATH is set and you're in a new PS session:
```powershell
pwsh.exe -NoProfile -Command "scoop <command>"
```

## Default Buckets

| Bucket | Source | Purpose |
|--------|--------|---------|
| `main` | ScoopInstaller/Main | Core CLI tools (~1550 manifests) |
| `extras` | ScoopInstaller/Extras | GUI apps, browsers, utilities (~2300 manifests) |
| `versions` | ScoopInstaller/Versions | Alternate versions, beta/rc (~580 manifests) |

```powershell
pwsh.exe -NoProfile -Command "& 'C:\Users\<user>\scoop\apps\scoop\current\bin\scoop.ps1' bucket add extras"
pwsh.exe -NoProfile -Command "& 'C:\Users\<user>\scoop\apps\scoop\current\bin\scoop.ps1' bucket add versions"
```

## aria2 (Parallel Downloads)

Scoop auto-detects aria2 for parallel chunked downloads:

```powershell
pwsh.exe -NoProfile -Command "& 'C:\Users\<user>\scoop\apps\scoop\current\bin\scoop.ps1' install aria2"
```

## Bucket Health Check

```powershell
pwsh.exe -NoProfile -Command "& 'C:\Users\<user>\scoop\apps\scoop\current\bin\scoop.ps1' bucket list"
```

Expected output:
```
Name         Source                                        Updated             Manifests
----         ------                                        -------             ---------
main         https://github.com/ScoopInstaller/Main        26.05.2026 20:30        1551
extras       https://github.com/ScoopInstaller/Extras      26.05.2026 20:32        2303
versions     https://github.com/ScoopInstaller/Versions    26.05.2026 21:03         583
```

**Red flag:** 0 manifests on a bucket means its git clone is broken.

## Repairing Broken Bucket Git State

### Symptom 1: `fatal: your current branch appears to be broken`

The bucket's git repo is in detached HEAD state with no valid commits — usually from an interrupted `scoop bucket add`. The bucket shows in `list` with 0 manifests.

**Fix sequence (in order):**

1. **Kill stale git processes** (they hold lock files):
   ```powershell
   Get-Process git* -ErrorAction SilentlyContinue | Stop-Process -Force
   ```

2. **Manually remove the broken bucket directory** (scoop bucket rm may fail since git lock files are held):
   ```powershell
   Remove-Item 'C:\Users\<user>\scoop\buckets\<bucket>' -Recurse -Force
   ```

3. **Remove the bucket registration from Scoop** (fails gracefully if already gone):
   ```powershell
   pwsh.exe -NoProfile -Command "& 'C:\Users\<user>\scoop\apps\scoop\current\bin\scoop.ps1' bucket rm <bucket>"
   ```

4. **Re-add the bucket** (full git clone):
   ```powershell
   pwsh.exe -NoProfile -Command "& 'C:\Users\<user>\scoop\apps\scoop\current\bin\scoop.ps1' bucket add <bucket>"
   ```

### Symptom 2: `The process cannot access the file '...\tmp_pack_*'`

Stale git lock files (`tmp_pack_*` in `.git\objects\pack\`) prevent both `scoop bucket rm` and `Remove-Item`. The lock is held by a git process that was orphaned.

Fix: Kill **all** `git*` processes first, **then** manually remove the directory, **then** scoop bucket rm, **then** re-add.

### Symptom 3: `WARN  The '<bucket>' bucket already exists.`

Bucket registered in Scoop config but directory is gone (or git is broken). Same fix sequence: manual Remove-Item the leftover dir → scoop bucket rm → scoop bucket add.

## Updating Scoop itself

```powershell
pwsh.exe -NoProfile -Command "& 'C:\Users\<user>\scoop\apps\scoop\current\bin\scoop.ps1' update"
```

If update aborts with `WARN  Uncommitted changes detected`, the scoop repo itself may be dirty. Fix:
```powershell
Set-Location 'C:\Users\<user>\scoop\apps\scoop\current'
git checkout .
git pull
```

## User PATH with Cyrillic Usernames

Windows username in Cyrillic (Пухаткин) causes path resolution issues from WSL. Always use the 8.3 short name when constructing paths. Find it via:
```bash
cmd.exe /c "dir C:\Users /x"
```
Example: `0C7E~1` for `Пухаткин`.

## Installing Winget via Scoop

Winget (v1.28.240) available in `main` bucket as a 206 MB msixbundle:

```powershell
scoop search winget  # winget (main), winget-preview (versions), winget-ps (main)
scoop install winget
```

### Slow Download Handling (GitHub from Russia)

206 MB frequently times out with default 120-300s timeout:

**Strategy 1: Disable aria2 first** (multi-connection can stall)
```powershell
scoop config aria2-enabled false
scoop install winget
```

**Strategy 2: Background download**
```shell
# Run in background with notify_on_complete
pwsh.exe -NoProfile -Command "Remove-Item 'C:\Users\<user>\scoop\cache\winget*' -Force -ErrorAction SilentlyContinue; & 'C:\Users\<user>\scoop\apps\scoop\current\bin\scoop.ps1' install winget"
# Check progress via cache file size:
ls -lh /mnt/c/Users/<shortname>/scoop/cache/winget*
```

**Strategy 3: Clear corrupt cache on hash failure**
```powershell
Remove-Item 'C:\Users\<user>\scoop\cache\winget*' -Force -ErrorAction SilentlyContinue
scoop install winget    # fresh download
```

**Post-install:** Scoop suggests `extras/vcredist2022` as a winget dependency. Install it too:
```powershell
scoop install extras/vcredist2022
```
Requires a Windows restart to complete. ~25 MB (x64: 17.9 MB + x86: 6.7 MB).

## Winget Source Limitations from Russia (Microsoft CDN)

After installation, `winget source update --disable-interactivity` may **fail or hang** on the `winget` (CDN) and `winget-font` sources while `msstore` succeeds:

| Source | Status from Russia | Cause |
|--------|-------------------|-------|
| `msstore` (Microsoft Store) | ✅ Works | Store API accessible |
| `winget` (cdn.winget.microsoft.com) | ❌ Timed out / Cancelled | CDN slow or blocked |
| `winget-font` | ❌ Timed out / Cancelled | Same CDN |

**Impact:** `winget search` falls back to `msstore` only, missing most CLI packages. Use Scoop as the primary manager (GitHub-based, works fine from Russia), and treat winget as a secondary source for Store apps.

**Fix:** Accept source agreements to suppress prompts:
```powershell
winget source update winget --accept-source-agreements
# Still may fail on the network level — that's fine, msstore works
```

## UniGetUI — GUI for Winget, Scoop, Chocolatey, Pip, Npm, etc.

Available in `extras` bucket:
```powershell
scoop search unigetui        # → unigetui 2026.1.10 (extras)
scoop info extras/unigetui   # → check version, license
scoop install extras/unigetui
```

| Detail | Value |
|--------|-------|
| Package | UniGetUI (formerly WingetUI) |
| Size | ~170 MB (zip, includes .NET runtime) |
| Source | https://github.com/Devolutions/UniGetUI |
| License | MIT |
| Supports | WinGet, Scoop, Chocolatey, Pip, Npm, .NET Tool, PowerShell Gallery |

### Notes
- Download is large (170 MB) and GitHub from Russia is slow — use background + cache resume:
  ```powershell
  # Check cache progress
  ls /mnt/c/Users/<shortname>/scoop/cache/unigetui*
  ```
- Scoop auto-resumes partial downloads from `.download` files in cache. If the download was interrupted, just re-run `scoop install`.
- If hash fails, remove cache and retry:
  ```powershell
  Remove-Item "$env:USERPROFILE\scoop\cache\unigetui*" -Force
  scoop install extras/unigetui
  ```

## Chocolatey Admin Rights via UniGetUI Install Options

Chocolatey **requires elevation** (Run as Administrator) for most operations — especially `choco upgrade`, `choco install`, and any writes to `C:\ProgramData\chocolatey\`.

### Symptom

```
Cannot create directory "C:\ProgramData\chocolatey\lib-bkp\chocolatey"
System.UnauthorizedAccessException: ⧽⧽⧽ ← Access is denied
```

This happens when UniGetUI runs in non-privileged mode and tries to invoke `choco` without elevation.

### Fix: Set RunAsAdministrator in UniGetUI Install Options

UniGetUI stores per-manager installation options as JSON files under:
```
<UniGetUI>\Settings\InstallationOptions\{Manager}.{PackageManager}.json
```

For Chocolatey, write:
```json
{"RunAsAdministrator":true}
```

To the file `Settings\InstallationOptions\Chocolatey.chocolatey.json` (create if absent).

**Path from WSL with Cyrillic username:**
```bash
write_file "/mnt/c/Users/0C7E~1/scoop/apps/unigetui/current/Settings/InstallationOptions/Chocolatey.chocolatey.json" '{"RunAsAdministrator":true}'
```

This tells UniGetUI to elevate Chocolatey operations via `Start-Process -Verb RunAs`. The UAC prompt appears per operation but Chocolatey no longer fails with access-denied.

### Winget Path Fix: WindowsApps Resolution

Some tools (UniGetUI, Chocolatey, third-party scripts) look for `winget.exe` specifically in `C:\Users\<user>\AppData\Local\Microsoft\WindowsApps\` — the standard Windows Store winget location. Since scoop installs winget to `C:\Users\<user>\scoop\apps\winget\current\`, these tools fail with:

```
"C:\Users\<user>\AppData\Local\Microsoft\WindowsApps\winget.exe"
не является внутренней или внешней командой
Ошибка: Не удается найти процесс "winget.exe"
```

The default `winget.cmd` in WindowsApps launches the Store-packaged App Installer (`Microsoft.DesktopAppInstaller_8wekyb3d8bbwe!winget`), which doesn't exist when winget is installed via scoop.

**Fix:** Copy the real winget.exe and its DLL dependency to WindowsApps:

```powershell
# Copy the actual winget.exe (not the scoop shim, which needs its .shim file)
Copy-Item 'C:\Users\<shortname>\scoop\apps\winget\current\winget.exe' `
          'C:\Users\<shortname>\AppData\Local\Microsoft\WindowsApps\winget.exe' -Force

# WindowsPackageManager.dll is required alongside winget.exe
Copy-Item 'C:\Users\<shortname>\scoop\apps\winget\current\WindowsPackageManager.dll' `
          'C:\Users\<shortname>\AppData\Local\Microsoft\WindowsApps\WindowsPackageManager.dll' -Force

# WindowsPackageManagerServer.exe is needed for some operations
Copy-Item 'C:\Users\<shortname>\scoop\apps\winget\current\WindowsPackageManagerServer.exe' `
          'C:\Users\<shortname>\AppData\Local\Microsoft\WindowsApps\WindowsPackageManagerServer.exe' -Force
```

Also update `winget.cmd` to point to the scoop-installed winget (not the packaged Store version):

```cmd
@echo off
REM winget wrapper → scoop-installed winget
"C:\Users\<shortname>\scoop\apps\winget\current\winget.exe" %*
```

**Note:** Creating a symlink (`New-Item -ItemType SymbolicLink`) would be cleaner but requires Administrator privileges. Copying the files directly works without elevation.

### UniGetUI: Running as Administrator (LNK Shortcuts)

UniGetUI needs elevation for Chocolatey and some Winget operations. Create admin-launch shortcuts:

1. Write a PowerShell launcher script to the UniGetUI app directory:
```powershell
# C:\Users\<shortname>\scoop\apps\unigetui\current\run-admin.ps1
Start-Process "C:\Users\<shortname>\scoop\apps\unigetui\current\UniGetUI.exe" -Verb RunAs
```

2. Create shortcuts pointing to `pwsh.exe` with the script as argument:
```powershell
$shell = New-Object -ComObject WScript.Shell

# Start Menu
$lnk = $shell.CreateShortcut([Environment]::GetFolderPath('StartMenu') + '\Programs\Scoop Apps\UniGetUI (Admin).lnk')
$lnk.TargetPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
$lnk.Arguments = '-NoProfile -WindowStyle Hidden -File "C:\Users\<shortname>\scoop\apps\unigetui\current\run-admin.ps1"'
$lnk.IconLocation = 'C:\Users\<shortname>\scoop\apps\unigetui\current\UniGetUI.exe,0'
$lnk.Save()

# Desktop
$lnk2 = $shell.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\UniGetUI (Admin).lnk')
$lnk2.TargetPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
$lnk2.Arguments = '-NoProfile -WindowStyle Hidden -File "C:\Users\<shortname>\scoop\apps\unigetui\current\run-admin.ps1"'
$lnk2.IconLocation = 'C:\Users\<shortname>\scoop\apps\unigetui\current\UniGetUI.exe,0'
$lnk2.Save()
```

The regular `UniGetUI` shortcut stays for non-admin browsing; the `(Admin)` variants trigger UAC on launch.

### Chocolatey: Forced Upgrade from WSL (Elevated)

When `choco upgrade chocolatey` fails with `System.UnauthorizedAccessException` on `C:\\ProgramData\\chocolatey\\`:

```powershell
# From WSL — use Start-Process -Verb RunAs to elevate
pwsh.exe -NoProfile -Command "Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile -Command \"choco upgrade chocolatey -y --no-progress\"' -Wait"
```

This opens a UAC prompt. The output goes to the elevated window (not captured by WSL). Verify after:

```powershell
pwsh.exe -NoProfile -Command "choco --version"
```

⚠️ **Important: Elevated session PATH differs.** The elevated PowerShell window starts in `C:\\Windows\\System32` with a SYSTEM-scoped PATH. If `choco` or `scoop` were added to the user's PATH, the elevated session may not find them.

**Always use full path in elevated commands:**
```powershell
Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile -Command \"& \\\"C:\\ProgramData\\chocolatey\\bin\\choco.exe\\\" upgrade chocolatey -y --no-progress\"' -Wait
```

For scoop from an elevated session:
```powershell
Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile -Command \"& \\\"C:\\Users\\<shortname>\\scoop\\apps\\scoop\\current\\bin\\scoop.ps1\\\" install <package>\"' -Wait
```

**Detection:** If an elevated `Start-Process -Wait` returns immediately with `DONE` but the command didn't actually execute, the binary wasn't found in PATH. Always use full paths for elevated operations.

### Aria2 Toggle for Slow/Stalling Downloads

GitHub downloads from Russia can stall with aria2 multi-connection. Toggle aria2 off/on:

```powershell
# Disable for large/slow downloads
scoop config aria2-enabled false

# Re-enable after
scoop config aria2-enabled true
```

When aria2 is disabled, scoop falls back to single-connection download (.msi/.zip via .NET HttpWebRequest). More stable but slower on high-latency links.

### Aria2 on WSL (for Windows-destined downloads)

When scoop's built-in aria2 (Windows) is slow or stalls, install aria2 on WSL for direct downloads to Windows paths. Useful for large files like winget MSIX (206 MB):

```bash
# Install Linux aria2 on WSL
sudo apt install aria2 -y

# Download directly to a Windows path (via /mnt/c/)
aria2c -x 10 -s 10 -d /tmp -o winget.msixbundle \
  "https://github.com/microsoft/winget-cli/releases/download/v1.28.240/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"

# Then copy to Windows Temp for installation
cp /tmp/winget.msixbundle /mnt/c/Users/<shortname>/AppData/Local/Temp/
```

⚠️ **GitHub redirect stalls:** aria2 may stall on GitHub's redirect chain (the download URL redirects through an expiring token URL). The file appears as 206M pre-allocated but the .aria2 control file remains. Workaround: use `curl -L` instead, which handles the redirect chain more reliably:

```bash
curl -Lo /mnt/c/Users/<shortname>/AppData/Local/Temp/winget.msixbundle \
  "https://github.com/microsoft/winget-cli/releases/download/v1.28.240/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
```

### AppX Reinstall Path (Alternative to Scoop Winget)

If the scoop-installed winget causes AppX registration issues (missing COM interfaces, path resolution errors), install the official AppX MSIX from GitHub releases:

```powershell
# 1. Remove existing scoop winget
scoop uninstall winget
Remove-Item "$env:USERPROFILE\scoop\cache\winget*" -Force -ErrorAction SilentlyContinue

# 2. Remove old broken AppX package (if any)
Get-AppxPackage -Name Microsoft.DesktopAppInstaller | Remove-AppxPackage

# 3. Download MSIX from GitHub (use curl or aria2 from WSL, ~206 MB)
curl -Lo "$env:TEMP\winget.msixbundle" `
  "https://github.com/microsoft/winget-cli/releases/download/v1.28.240/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"

# 4. Install the AppX package (registers COM interfaces, creates App Execution Alias)
Add-AppxPackage -Path "$env:TEMP\winget.msixbundle"
```

**Network:** The 206 MB download from GitHub may be slow from Russia. If available, route through a VPN (Germany-based VPNs typically have full CDN access). Without VPN, the scoop-install path (which extracts from an already-downloaded cache) is more reliable.

**After AppX install:**
- Winget CLI available via App Execution Alias from CMD/PowerShell
- COM API (`Get-WinGetPackage`, `Get-WinGetVersion`) works from native Windows processes
- The junction at `%LOCALAPPDATA%\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\` is auto-created
- `WindowsPackageManagerServer.exe` runs as a COM background server

### PATH Caveat: Existing Sessions

After adding Scoop shims to user PATH via:
```powershell
[Environment]::SetEnvironmentVariable('Path', $userPath + ';' + $shims, 'User')
```

Existing `pwsh.exe -NoProfile` sessions **do NOT see the new PATH** — they load environment only at process start. Use the full scoop.ps1 path instead:
```powershell
pwsh.exe -NoProfile -Command "& 'C:\Users\<shortname>\scoop\apps\scoop\current\bin\scoop.ps1' <command>"
```
Or start a fresh PowerShell terminal (e.g., new Windows Terminal tab).

Scoop's default search is slow (iterates manifests). `scoop-search` is a compiled Rust replacement:

```powershell
scoop install main/scoop-search
# 703 KB, fast install, MIT license
```

Usage: `scoop search <term>` works as drop-in replacement after install (shim replaces built-in).

To hook it as the default `scoop search` in PowerShell profiles:
```powershell
. ([ScriptBlock]::Create((& scoop-search --hook | Out-String)))
```

## Checking Package Size Before Install

Use `scoop info` or inspect the manifest URL with a HEAD request. From WSL:

```powershell
# scoop info shows version and description but not size
scoop info extras/unigetui

# Get actual download size from the URL in the manifest
# From ~\scoop\buckets\<bucket>\bucket\<package>.json
curl -sIL "https://github.com/Devolutions/UniGetUI/releases/download/..." | grep -i "^content-length:" | tail -1
```

**User preference:** Always show package download size before installing packages ≥ 50 MB. Present as a table:

| Component | Size |
|-----------|------|
| `vc_redist.x64.exe` | 17.9 MB |
| `vc_redist.x86.exe` | 6.7 MB |
| **Total** | **24.6 MB** |

## WinGet COM API Limitation from WSL (UNC Working Directory)

The WinGet COM API (used by `Get-WinGetPackage`, UniGetUI's WinGet manager, and the `Microsoft.WinGet.Client` PowerShell module) **does not work when invoked from WSL's PowerShell** because of a UNC working directory issue.

### Symptom

```
Get-WinGetVersion: An error occurred trying to start process
'C:\Users\<user>\AppData\Local\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe'
with working directory '\\wsl.localhost\Ubuntu-22.04\home\user'. Access denied.
```

### Root Cause

- AppX-packaged processes (like WinGet's COM server) **cannot start from a UNC path** as their working directory
- When `pwsh.exe` is launched from WSL (`\\wsl.localhost\...`), the process inherits the UNC working directory
- Even `Set-Location C:` within PowerShell does NOT change the *process's initial working directory* used by AppX activation
- The `Microsoft.WinGet.Client` module calls `CreateProcess` with the original process CWD

### Impact

| Component | From WSL pwsh.exe | From native Windows PS |
|-----------|-------------------|----------------------|
| `winget --version` (CLI) | ✅ Works (scoop shim) | ✅ Works |
| `Get-WinGetVersion` (COM) | ❌ UNC path error | ✅ Works |
| `Get-WinGetPackage` (COM) | ❌ E_NOINTERFACE | ✅ Works |
| UniGetUI native GUI | ✅ Works (Windows CWD) | ✅ Works |

### Workaround

- **UniGetUI** runs as a native Windows GUI with a `C:\Windows\System32` CWD (when elevated) — it works fine
- **Admin shortcuts** using `Start-Process -Verb RunAs` create a new process with a Windows CWD — works fine
- **PowerShell scripts** from WSL: use `pwsh.exe -WorkingDirectory C:\ -Command "..."` to set CWD before running WinGet cmdlets (but the new process may not inherit PSModulePath correctly)
- **Reliable approach:** write WinGet scripts to `%TEMP%` and execute via `Start-Process powershell -Verb RunAs` from `pwsh.exe`

### AppX junction for winget

The `Microsoft.WinGet.Client` module looks for winget at:
```
C:\Users\<user>\AppData\Local\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe
```

This should be a junction/symlink created by the AppX installer pointing to:
```
C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_<version>_x64__8wekyb3d8bbwe\winget.exe
```

If the junction is missing (e.g., after scoop install that didn't register the AppX), create it:
```powershell
# Find the AppX package location
$pkg = Get-AppxPackage -Name Microsoft.DesktopAppInstaller
# Create junction (from elevated PowerShell or from Windows PS, not WSL)
cmd /c mklink /J "C:\Users\<user>\AppData\Local\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" "$($pkg.InstallLocation)"
```

The junction should contain winget.exe, WindowsPackageManager.dll, and WindowsPackageManagerServer.exe — all needed for the COM API to initialize.

Check if the AppX package is installed:
```powershell
Get-AppxPackage -Name Microsoft.DesktopAppInstaller | Select-Object Name, Version, InstallLocation, Status
```

### Registered WinGet COM Server

The `WindowsPackageManagerServer.exe` should be running in the background for COM API calls to work. It auto-starts when winget operations are invoked. Verify:
```powershell
Get-Process WindowsPackageManagerServer -ErrorAction SilentlyContinue
```

If the server isn't running, it starts automatically on first winget COM call. The `E_NOINTERFACE` error (-2147467262 / 0x80004002) indicates the WinRT class `Microsoft.Management.Deployment.PackageManager` interface isn't properly registered — fix the AppX junction first, then verify the package signature hasn't been revoked.

## Real Session Transcript (May 2026)

Initial state:
- `scoop version` → v0.5.3, main bucket OK, extras/versions at 0 manifests
- `fatal: your current branch appears to be broken` on extras and versions git repos
- `scoop bucket add extras` timed out on first attempt (GitHub slow, 60s not enough)
- `scoop bucket rm extras` failed — `The process cannot access the file '...\tmp_pack_*' because it is being used by another process.`

Fix applied:
1. `Get-Process git* | Stop-Process -Force`
2. `Remove-Item 'C:\Users\0C7E~1\scoop\buckets\versions' -Recurse -Force`
3. `scoop bucket rm versions` (after dir gone → "not found" → OK)
4. `scoop bucket add versions` (300s timeout, cloned successfully)
5. Same for extras bucket — also fixed main's git state with `git checkout master && git pull`

Final state: main: 1551 manifests, extras: 2303, versions: 583, aria2 installed, all healthy.
