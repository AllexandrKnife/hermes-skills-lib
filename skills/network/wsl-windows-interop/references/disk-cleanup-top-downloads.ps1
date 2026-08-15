$downloads = "$env:USERPROFILE\Downloads"
$files = Get-ChildItem -Path $downloads -Recurse -File -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending | Select-Object -First 10
Write-Output ("{0,-80} {1,10} {2,15}" -f "File", "Size", "Date")
Write-Output ("-"*110)
foreach ($f in $files) {
    $mb = [math]::Round($f.Length / 1MB, 1)
    $name = $f.FullName.Substring($downloads.Length + 1)
    $date = $f.LastWriteTime.ToString("yyyy-MM-dd")
    Write-Output ("{0,-80} {1,8} MB {2,15}" -f $name, $mb, $date)
}
