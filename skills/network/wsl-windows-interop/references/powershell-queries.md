# Working PowerShell Queries from WSL

Tested on: Windows 10 LTSC 21H2 (build 19044) from Ubuntu 22.04 WSL2

## Simple Queries (inline -Command, work reliably)

```bash
# OS info
powershell.exe -Command "gwmi Win32_OperatingSystem"
# Returns: Caption, Version, LastBootUpTime, TotalVisibleMemorySize (KB),
#          FreePhysicalMemory (KB), NumberOfProcesses

# System model + RAM
powershell.exe -Command "gwmi Win32_ComputerSystem -Property TotalPhysicalMemory,Model,Manufacturer"
# Returns: Manufacturer, Model, TotalPhysicalMemory (bytes)

# Disks (DriveType=3 = local disk)
powershell.exe -Command "gwmi Win32_LogicalDisk -filter DriveType=3"
# Returns: DeviceID, FreeSpace (bytes), Size (bytes), VolumeName

# CPU
powershell.exe -Command "gwmi Win32_Processor"
# Returns: Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed

# Users
powershell.exe -Command "Get-ChildItem 'C:\Users' -Directory | Select-Object Name"

# Network discovery from WSL2
powershell.exe -Command "Get-NetNeighbor -IPAddress 192.168.1.X"  # MAC of specific host
powershell.exe -Command "Get-NetNeighbor -AddressFamily IPv4"       # Full ARP table

# MAC OUI lookup
curl -s "https://api.macvendors.com/48-5C-2C"                     # returns manufacturer name
```

## Complex Queries (use .ps1 file on Windows FS)

### Write file to Windows filesystem first
```bash
cp /tmp/myscript.ps1 /mnt/c/Users/Public/myscript.ps1
cd /mnt/c && powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Public\myscript.ps1"
```

### Get directory size in MB
```powershell
$path = "C:\SomeFolder"
if (Test-Path $path) {
    $sum = (Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    if ($sum) { [math]::Round($sum/1MB, 1) } else { 0 }
}
```

### Full Windows disk analysis (targeted — avoids C:\ recursive timeout)
```powershell
$user = $env:USERNAME

# Phase 1: User home folders
@("$env:USERPROFILE\Desktop","$env:USERPROFILE\Downloads","$env:USERPROFILE\Documents") | ForEach-Object {
    if (Test-Path $_) {
        $size = (Get-ChildItem $_ -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $gb = [math]::Round($size/1GB, 2)
        Write-Output ("{0,-45} {1,8:N2} GB" -f $_, $gb)
    }
}

# Phase 2: Known caches
$caches = @(
    "$env:USERPROFILE\AppData\Local\Temp",
    "$env:USERPROFILE\.cache",
    "$env:USERPROFILE\AppData\Local\npm-cache",
    "$env:USERPROFILE\AppData\Local\pip",
    "$env:USERPROFILE\.npm",
    "$env:USERPROFILE\.rustup",
    "$env:USERPROFILE\.cargo\registry",
    "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Cache",
    "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Cache"
)
foreach ($p in $caches) {
    if (Test-Path $p) {
        $size = (Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $mb = [math]::Round($size/1MB, 1)
        Write-Output ("{0,-60} {1,10:N1} MB" -f $p, $mb)
    }
}

# Phase 3: Large AppData subfolders (slow - target specific dirs)
$ad = @("$env:USERPROFILE\AppData\Local\Programs","$env:USERPROFILE\AppData\Local\Docker","$env:USERPROFILE\AppData\Local\JetBrains")
foreach ($p in $ad) {
    if (Test-Path $p) {
        $size = (Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $gb = [math]::Round($size/1GB, 2)
        if ($gb -gt 0.1) { Write-Output ("{0,-50} {1,8:N2} GB" -f $p, $gb) }
    }
}

# Phase 4: System folders summary
@("C:\Users","C:\ProgramData","C:\Program Files","C:\Program Files (x86)") | ForEach-Object {
    $size = (Get-ChildItem $_ -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    $gb = [math]::Round($size/1GB, 1)
    Write-Output ("{0,-30} {1,8:N1} GB" -f $_, $gb)
}
```

### Check Downloads folder contents (find old files)
```powershell
# Show files by year, grouped
Get-ChildItem "$env:USERPROFILE\Downloads" -File | Group-Object { $_.LastWriteTime.Year } | Select-Object Name, Count, @{N='SizeMB';E={[math]::Round(($_.Group | Measure-Object Length -Sum).Sum/1MB,1)}} | Sort-Object Name -Descending

# Find installers (.exe, .msi) that can be safely removed
Get-ChildItem "$env:USERPROFILE\Downloads" -Include *.exe,*.msi,*.msu -Recurse -File | Select-Object Name, @{N='SizeMB';E={[math]::Round($_.Length/1MB,1)}}, LastWriteTime | Format-Table -AutoSize
```

### List recent vs old files in a folder
```powershell
# Oldest 20 files
Get-ChildItem "$env:USERPROFILE\Downloads" -File | Sort-Object LastWriteTime | Select-Object -First 20 Name, LastWriteTime, @{N='MB';E={[math]::Round($_.Length/1MB,1)}}

# Newest 20 files
Get-ChildItem "$env:USERPROFILE\Downloads" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 20 Name, LastWriteTime, @{N='MB';E={[math]::Round($_.Length/1MB,1)}}
```

### Recycle Bin
```powershell
$shell = New-Object -ComObject Shell.Application
$rb = $shell.NameSpace(0xa)
"Items: $($rb.Items().Count)"
$sum = 0; foreach ($i in $rb.Items()) { $sum += $i.Size }
"Total: $([math]::Round($sum/1MB,0)) MB"
```

## What Does NOT Work

- `Get-CimInstance` with complex pipes inline (encoding breaks)
- Multi-line `.ps1` files from `/tmp/` (PowerShell can't read WSL filesystem)
- `cmd.exe /c "chcp 65001 >nul & systeminfo | findstr ..."` (backgrounding detection + encoding)
- Any inline `-Command` with `$_.Property` — the shell mangles `$_` into `/mnt/c/`
- `wsl.exe --status` piped through iconv with BOM issues
