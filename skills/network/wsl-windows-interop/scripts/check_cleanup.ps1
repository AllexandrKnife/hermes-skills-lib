# Targeted Windows disk-cleanup scan for admin-less machines (run from WSL):
#   cp scripts/check_cleanup.ps1 /mnt/c/Users/Public/check_cleanup.ps1
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Public\check_cleanup.ps1"
# Prints: "<size MB>  <seconds>  <path>" — only folders that exist are scanned.
# Tuned: ~30s total for 18 targeted folders. Do NOT add whole-AppData enumeration
# here — sizing every AppData\Local subfolder recursively takes 300s+ and hangs.
# Numbers use InvariantCulture so WSL-side parsing isn't hit by the RU-locale space
# thousands separator (which garbles to "�" through WSL output encoding).
$ErrorActionPreference = 'SilentlyContinue'
$ci = [System.Globalization.CultureInfo]::InvariantCulture
$u = $env:USERPROFILE
$targets = @(
    "$u\AppData\Local\Temp",
    "$u\AppData\Local\Microsoft\Edge\User Data\Default\Cache",
    "$u\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache",
    "$u\AppData\Local\Google\Chrome\User Data\Default\Cache",
    "$u\AppData\Local\Google\Chrome\User Data\Default\Code Cache",
    "$u\AppData\Local\npm-cache",
    "$u\.npm",
    "$u\.cache",
    "$u\AppData\Local\pip",
    "$u\.rustup",
    "$u\.cargo\registry",
    "$u\AppData\Local\Docker",
    "$u\AppData\Local\JetBrains",
    "$u\AppData\Local\Programs",
    "$u\AppData\Roaming\npm",
    "$u\AppData\Roaming\Code",
    "$u\.vscode\extensions",
    "$u\Downloads"
)
foreach ($p in $targets) {
    if (-not (Test-Path $p)) { continue }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $s = (Get-ChildItem $p -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    $sw.Stop()
    $mb = if ($s) { $s/1MB } else { 0 }
    Write-Output ("{0,10} MB  {1,5}s  {2}" -f [math]::Round($mb,1).ToString('0.0',$ci), $sw.Elapsed.TotalSeconds.ToString('0',$ci), $p)
    [Console]::Out.Flush()
}
Write-Output "=== DONE ==="
