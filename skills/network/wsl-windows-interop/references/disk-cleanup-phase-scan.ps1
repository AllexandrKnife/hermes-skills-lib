# Phase 1: User Home Folders
Write-Output "=== User Home Folders ==="
@("$env:USERPROFILE\Desktop","$env:USERPROFILE\Downloads","$env:USERPROFILE\Documents") | ForEach-Object {
    if (Test-Path $_) {
        $size = (Get-ChildItem $_ -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $gb = [math]::Round($size/1GB, 2)
        Write-Output ("{0,-45} {1,8:N2} GB" -f $_, $gb)
    }
}

# Phase 2: Known Caches
Write-Output "`n=== Known Caches ==="
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
        $size = (Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $mb = [math]::Round($size/1MB, 1)
        Write-Output ("{0,-60} {1,10:N1} MB" -f $p, $mb)
    }
}

# Phase 3: Large AppData Subfolders (targeted — no full scan)
Write-Output "`n=== Large AppData Subfolders ==="
$ad = @(
    "$env:USERPROFILE\AppData\Local\Programs",
    "$env:USERPROFILE\AppData\Local\Docker",
    "$env:USERPROFILE\AppData\Local\JetBrains"
)
foreach ($p in $ad) {
    if (Test-Path $p) {
        $size = (Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $gb = [math]::Round($size/1GB, 2)
        if ($gb -gt 0.1) { Write-Output ("{0,-50} {1,8:N2} GB" -f $p, $gb) }
    }
}

# Phase 4: System Folders Summary (fast — one level only)
Write-Output "`n=== System Folders Summary ==="
@("C:\Users","C:\ProgramData","C:\Program Files","C:\Program Files (x86)") | ForEach-Object {
    $size = (Get-ChildItem $_ -Recurse -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    $gb = [math]::Round($size/1GB, 1)
    Write-Output ("{0,-30} {1,8:N1} GB" -f $_, $gb)
}
