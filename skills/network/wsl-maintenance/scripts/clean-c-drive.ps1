# clean-c-drive.ps1
# Safe C: drive cleanup — only temp files, caches, npm-cache, browser caches
# Usage from WSL: powershell.exe -ExecutionPolicy Bypass -File C:\Windows\Temp\clean-c-drive.ps1
# (copy to C:\Windows\Temp first: cp /tmp/clean-c-drive.ps1 /mnt/c/Windows/Temp/)

Write-Host "=== C: Drive Safe Cleanup ==="
$c = Get-PSDrive C
$before = $c.Free
Write-Host ("Free before: " + [math]::Round($before/1GB, 1) + " GB")
Write-Host ""

# --- User %TEMP% ---
$ut = $env:TEMP
Write-Host ("Cleaning User Temp: " + $ut)
Get-ChildItem $ut -Force -ErrorAction SilentlyContinue | 
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  done"

# --- Windows Temp ---
$wt = "C:\Windows\Temp"
if (Test-Path $wt) {
    Write-Host ("Cleaning Windows Temp: " + $wt)
    Remove-Item "$wt\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  done"
}

# --- npm-cache ---
$npm = $env:LOCALAPPDATA + "\npm-cache"
if (Test-Path $npm) {
    Write-Host "Cleaning npm-cache..."
    Get-ChildItem $npm -Force -ErrorAction SilentlyContinue | 
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  done"
}

# --- pip cache ---
$pip = $env:LOCALAPPDATA + "\pip\Cache"
if (Test-Path $pip) {
    Write-Host "Cleaning pip cache..."
    Remove-Item "$pip\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  done"
}

# --- Browser caches (safe — recreated on next browser launch) ---
$browsers = @(
    $env:LOCALAPPDATA + "\Google\Chrome\User Data\Default\Cache",
    $env:LOCALAPPDATA + "\Google\Chrome\User Data\Default\Code Cache",
    $env:LOCALAPPDATA + "\Microsoft\Edge\User Data\Default\Cache"
)
foreach ($b in $browsers) {
    if (Test-Path $b) {
        Write-Host ("Cleaning " + $b)
        Remove-Item "$b\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  done"
    }
}

Write-Host ""
Write-Host "=== Result ==="
$c = Get-PSDrive C
$after = $c.Free
Write-Host ("Free after:  " + [math]::Round($after/1GB, 1) + " GB")
Write-Host ("Freed:      " + [math]::Round(($after-$before)/1MB, 0) + " MB")
