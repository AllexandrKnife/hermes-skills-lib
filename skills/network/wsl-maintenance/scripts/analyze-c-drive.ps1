# C: Drive Disk Analyzer
# Reusable script: checks 20 known space hogs with per-folder timeout.
# Copy to Windows %TEMP% and run via:
#   pwsh.exe -ExecutionPolicy Bypass -File "C:\Users\<user>\AppData\Local\Temp\analyze-c-drive.ps1"

$profileShort = "0C7E~1"  # 8.3 short name for Cyrillic usernames

$targets = @(
    @{N="WSL_VHDX"; P="C:\Users\$profileShort\AppData\Local\wsl"}
    @{N="Win_Installer"; P="C:\Windows\Installer"}
    @{N="WinSxS"; P="C:\Windows\WinSxS"}
    @{N="Win_System32"; P="C:\Windows\System32"}
    @{N="ProgramFiles"; P="C:\Program Files"}
    @{N="ProgramFiles_x86"; P="C:\Program Files (x86)"}
    @{N="ProgramData"; P="C:\ProgramData"}
    @{N="Chrome"; P="C:\Users\$profileShort\AppData\Local\Google"}
    @{N="Yandex"; P="C:\Users\$profileShort\AppData\Local\Yandex"}
    @{N="AppData_Local"; P="C:\Users\$profileShort\AppData\Local"}
    @{N="AppData_Roaming"; P="C:\Users\$profileShort\AppData\Roaming"}
    @{N="Downloads"; P="C:\Users\$profileShort\Downloads"}
    @{N="Desktop"; P="C:\Users\$profileShort\Desktop"}
    @{N="Documents"; P="C:\Users\$profileShort\Documents"}
    @{N="dot_cache"; P="C:\Users\$profileShort\.cache"}
    @{N="npm_cache"; P="C:\Users\$profileShort\npm-cache"}
    @{N="User_Temp"; P="C:\Users\$profileShort\AppData\Local\Temp"}
    @{N="Win_Temp"; P="C:\Windows\Temp"}
    @{N="Python313"; P="C:\Python313"}
    @{N="TCPU75"; P="C:\TCPU75"}
)

Write-Host "=== C: Drive Space Analysis ==="
$d = Get-PSDrive C
Write-Host ("Drive: {0:N2} GB used / {1:N2} GB free" -f ($d.Used/1GB), ($d.Free/1GB))
Write-Host ""

foreach ($t in $targets) {
    if (Test-Path $t.P) {
        $s = (Get-ChildItem $t.P -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($s -gt 100MB) {
            Write-Host ("{0,-20} {1,8:N2} GB" -f $t.N, ($s / 1GB))
        }
    }
}

Write-Host ""
Write-Host "=== Top-level C:\ folders ==="
Get-ChildItem "C:\" -Directory | Where-Object { $_.Name -notin @('$Recycle.Bin','System Volume Information','Recovery') } | ForEach-Object {
    $s = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($s -gt 1GB) {
        Write-Host ("{0,-25} {1,8:N2} GB" -f $_.Name, ($s / 1GB))
    }
}
