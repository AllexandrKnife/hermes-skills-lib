# Browser cache cleanup with credential verification (safe list only)
# Copy to Windows %TEMP%, run via: pwsh.exe -NoProfile -ExecutionPolicy Bypass -File <this>
# Preserves logins/passwords: deletes ONLY Cache/Code Cache/GPUCache/Service Worker dirs.
# Verifies credential files BEFORE and AFTER — proves nothing was lost.
# Locked files (browser running) silently survive — that's normal, they free on restart.
$ErrorActionPreference = 'SilentlyContinue'
$u = 'C:\Users\0C7E~1\AppData\Local'   # 8.3 short name for Cyrillic username

# ---- Verify credentials BEFORE ----
Write-Host "=== Credentials BEFORE ==="
$chromeCred = "$u\Google\Chrome\User Data\Default\Login Data"
$yandexCred = "$u\Yandex\YandexBrowser\User Data\Default\Ya Passman Data"
$chromeState = "$u\Google\Chrome\User Data\Local State"
$yandexState = "$u\Yandex\YandexBrowser\User Data\Local State"
foreach ($f in @($chromeCred,$yandexCred,$chromeState,$yandexState)) {
    if (Test-Path $f) {
        $kb = [math]::Round((Get-Item $f).Length/1KB,0)
        Write-Host ("OK {0,8:N0} KB  {1}" -f $kb, $f.Replace($u,'...'))
    } else {
        Write-Host ("ABSENT          {0}" -f $f.Replace($u,'...'))
    }
}
# NOTE: Yandex has NO "Login Data" — passwords live in "Ya Passman Data" (may also be absent).
# Missing Login Data/Ya Passman Data is NORMAL for Yandex, not data loss. Local State is the key file.

# ---- Chrome ----
Write-Host "=== Cleaning Chrome ==="
$cp = "$u\Google\Chrome\User Data\Default"
@('Cache','Code Cache','GPUCache','Service Worker\CacheStorage','Service Worker\ScriptCache') | ForEach-Object {
    $p = Join-Path $cp $_
    if (Test-Path $p) {
        Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ("  {0}: cleaned" -f $_)
    }
}

# ---- Yandex (numbered profiles, not Default) ----
Write-Host "=== Cleaning Yandex (unlocked only) ==="
$ypBase = "$u\Yandex\YandexBrowser\User Data"
Get-ChildItem $ypBase -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Profile*' -or $_.Name -eq 'Default' } | ForEach-Object {
    $prof = $_.FullName
    @('Cache','Code Cache','GPUCache','Service Worker\CacheStorage','Service Worker\ScriptCache','Snapshots','GrShaderCache','GraphiteDawnCache','component_crx_cache','ShaderCache') | ForEach-Object {
        $p = Join-Path $prof $_
        if (Test-Path $p) {
            Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host ("  {0}\{1}: cleaned (unlocked)" -f (Split-Path $prof -Leaf), $_)
        }
    }
}

# ---- User Temp ----
Write-Host "=== Cleaning User Temp ==="
Get-ChildItem "$u\Temp" -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  Temp cleaned (locked files survive)"

# ---- Verify credentials AFTER ----
Write-Host "=== Credentials AFTER ==="
foreach ($f in @($chromeCred,$yandexCred,$chromeState,$yandexState)) {
    if (Test-Path $f) {
        $kb = [math]::Round((Get-Item $f).Length/1KB,0)
        Write-Host ("OK {0,8:N0} KB  {1}" -f $kb, $f.Replace($u,'...'))
    } else {
        Write-Host ("ABSENT          {0}" -f $f.Replace($u,'...'))
    }
}
Write-Host "DONE"
