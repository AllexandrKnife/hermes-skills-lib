# AppX Winget issues from WSL

## Issue: COM API fails with "Access Denied"

### Symptom
```
Get-WinGetVersion: An error occurred trying to start process '...winget.exe' with working directory '\\wsl.localhost\Ubuntu-22.04\home\user'. Access denied.
```

### Root cause
Windows AppX security restricts AppX-packaged applications from launching with a working directory on a UNC path (`\\wsl.localhost\...`). PowerShell 7 launched from WSL inherits the WSL UNC path as its working directory.

This affects:
- `Get-WinGetVersion`, `Get-WinGetPackage` (PowerShell cmdlets)
- `Microsoft.WinGet.Client` module
- UniGetUI's WinGet manager (via COM API, **only** if launched from WSL)

### NOT affected
- `winget.exe` CLI called via **full path** from pwsh.exe
  ```
  pwsh -NoProfile -Command "& 'C:\Program Files\WindowsApps\...\winget.exe' --version"
  # This works
  ```
- UniGetUI launched from Windows (Start Menu, Desktop) — runs natively

### Workaround
There is no clean workaround from WSL. The fix is to run Windows-native tools (UniGetUI, native PowerShell) from Windows context, not through WSL's pwsh.exe.

### Test if winget works
```powershell
$winget = "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_1.28.240.0_x64__8wekyb3d8bbwe\winget.exe"
if (Test-Path $winget) { & $winget --version }
```
If this prints a version, the COM API is also registered (for native-Windows callers).

## Issue: App Execution Alias missing from WindowsApps

### Symptom
```
"C:\Users\Пухаткин\AppData\Local\Microsoft\WindowsApps\winget.exe" не является внутренней или внешней командой
```

### Fix
Create a junction from WindowsApps to the real AppX install location:
```powershell
cmd /c mklink /J "C:\Users\<user>\AppData\Local\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
```
Find the actual path with:
```powershell
(Get-AppxPackage -Name Microsoft.DesktopAppInstaller).InstallLocation
```
