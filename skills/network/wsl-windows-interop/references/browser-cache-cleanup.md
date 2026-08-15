# Browser Cache Cleanup from WSL (keep logins/passwords)

Verified 2026-07-31 on dkolchin's machine (Yandex Browser + Edge + Chrome).

## Why this exists

User asked: «почисти YandexBrowser — так чтобы логины и пароли сохранились».
Standard Chromium assumption (`Login Data` file) FAILED for Yandex — see below.

## Critical: where passwords actually live

| Browser | Password store | Encryption keys |
|---|---|---|
| Chrome / Edge | `User Data\Default\Login Data` (SQLite) | `User Data\Local State` |
| Yandex | `User Data\Default\Ya Passman Data` (~384 KB) | `User Data\Local State` |

Yandex has NO `Login Data` file. `Test-Path '...\Default\Login Data'` → False is NORMAL.
Don't abort the cleanup over it — check `Ya Passman Data` instead.
Also present but keep: `Preferences`, `Web Data`, `Account Web Data`, `Ya Autofill Data`,
`Bookmarks`, `History`, `Favicons`, `Cookies` (session cookies — deleting logs the user out).

## Procedure

1. Check running browsers (Yandex process name is `browser`):
```bash
powershell.exe -NoProfile -Command "Get-Process -Name 'browser','chrome','msedge' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName -Unique"
```
2. Close target browser with user consent:
```bash
powershell.exe -NoProfile -Command "Get-Process -Name 'browser' -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep -Seconds 3"
```
3. Snapshot credential files BEFORE (size + existence):
```bash
powershell.exe -NoProfile -Command "
\$pm = 'C:\Users\dkolchin\AppData\Local\Yandex\YandexBrowser\User Data\Default\Ya Passman Data';
'Passman: ' + (Test-Path \$pm) + '  (' + [math]::Round((Get-Item \$pm).Length/1KB,0) + ' KB)';
'Local State: ' + (Test-Path 'C:\Users\dkolchin\AppData\Local\Yandex\YandexBrowser\User Data\Local State')"
```
4. Delete only cache folders (this exact list worked):
```powershell
$ud = 'C:\Users\dkolchin\AppData\Local\Yandex\YandexBrowser\User Data'
$def = "$ud\Default"
$caches = @(
  "$def\Cache", "$def\Code Cache", "$def\GPUCache", "$def\Service Worker",
  "$ud\Snapshots", "$ud\AsrSubtitles", "$ud\component_crx_cache",
  "$ud\ShaderCache", "$ud\GrShaderCache", "$ud\GraphiteDawnCache",
  "$ud\Crashpad", "$ud\BrowserMetrics", "$ud\DeferredBrowserMetrics"
)
foreach ($c in $caches) { if (Test-Path $c) { Remove-Item $c -Recurse -Force } }
```
5. Re-verify credential files (Test-Path + size) — they must be identical to step 3.
6. Confirm freed space: `df -h /mnt/c | tail -1`.

## Measured sizes (dkolchin, 2026-07-31)

Yandex `AppData\Local\Yandex` breakdown (before):
- YandexBrowser\User Data: 4.9 GB (Default profile alone 3.86 GB)
- Default subfolders >20 MB: Service Worker 2701 MB, Code Cache 370 MB, Cache 246 MB,
  IndexedDB 155 MB, Local Storage 41 MB
- User Data top-level: Snapshots 613 MB, AsrSubtitles 106 MB, component_crx_cache 78 MB

After purge: User Data 759 MB. Disk C: 8.7 GB → 12 GB free.

Chrome/Edge cache folders (same scheme): `Default\Cache`, `Default\Code Cache`,
`Default\GPUCache`, `Default\Service Worker`. Edge total ~1 GB, Chrome ~855 MB.

## Pitfalls

- Browser MUST be closed; locked cache files are skipped silently (like Temp leftovers).
- Full `AppData\Local` recursive sizing timed out at 300s — size per-app, one subdir at a time.
- After purge, Yandex may ask for the master password on first login (if one was set) — expected, not a data loss.
