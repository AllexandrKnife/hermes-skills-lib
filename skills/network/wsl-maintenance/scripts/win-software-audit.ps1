# win-software-audit.ps1
# Windows software inventory — list installed programs from WSL.
# Run via: pwsh.exe -ExecutionPolicy Bypass -File <path>
# Usage: audit, group-by-size, or filter-out-microsoft

param(
    [ValidateSet('list','group','size','noise')]
    [string]$Mode = 'list',

    [switch]$WithSizes
)

$paths = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$items = Get-ItemProperty $paths | Where-Object { $_.DisplayName }

switch ($Mode) {
    'list' {
        $items | Sort-Object DisplayName | ForEach-Object {
            $name = $_.DisplayName -replace '\r?\n', ' '
            $size = if ($_.EstimatedSize) { [math]::Round($_.EstimatedSize / 1MB, 1) } else { 0 }
            if ($WithSizes) {
                "$name  //  ${size}MB"
            } else {
                $name
            }
        }
    }

    'size' {
        $items | Sort-Object { $_.EstimatedSize } -Descending |
            Where-Object { $_.EstimatedSize -gt 0 } |
            ForEach-Object {
                $name = $_.DisplayName -replace '\r?\n', ' '
                $mb = [math]::Round($_.EstimatedSize / 1MB, 1)
                "{0,10:N1} MB  {1}" -f $mb, $name
            }
    }

    'group' {
        # Group into user-meaningful categories by keyword matching
        $grouped = @{}
        $unk = @()

        $items | Sort-Object DisplayName | ForEach-Object {
            $name = $_.DisplayName -replace '\r?\n', ' '
            $pub = if ($_.Publisher) { $_.Publisher } else { "Unknown" }
            $size = if ($_.EstimatedSize) { [math]::Round($_.EstimatedSize / 1MB, 1) } else { 0 }

            $cat = "Other"
            if ($name -match '(?i)(\.NET\s+(Workload|SDK|Runtime|Host|Targeting|Toolset|Template|Mono|Emscripten)|ASP\.NET|MAUI|Android|iOS|tvOS|MacCatalyst|macOS.*Manifest)') { $cat = ".NET SDK / Workloads" }
            elseif ($name -match '(?i)(Windows SDK|WinAppDeploy|Universal CRT|WinRT\s+Intellisense|Windows\s+App\s+Certification|Windows\s+(Desktop|IoT|Mobile|Team)\s+Extension|SDK\s+ARM)') { $cat = "Windows SDK" }
            elseif ($name -match '(?i)(Visual\s+(Studio|C\+\+)\s+\d{4}.*Debug|vs_.*msi|VS\s+Script\s+Debugging|Visual\s+Studio\s+Setup|Kits\s+Configuration)') { $cat = "Visual Studio / Debug Runtimes" }
            elseif ($name -match '(?i)(Python\s+\d+\.\d+\.\d+)') { $cat = "Python" }
            elseif ($name -match '(?i)(PowerShell\s+7|pwsh)') { $cat = "PowerShell" }
            elseif ($name -match '(?i)(NVIDIA|PhysX|FrameView)') { $cat = "NVIDIA" }
            elseif ($name -match '(?i)(Lenovo|MarketResearch|hpp|Scan\s+To|SPDS)') { $cat = "Vendor Bloatware" }
            elseif ($name -match '(?i)(Adobe\s+Acrobat|Adobe\s+Refresh)') { $cat = "Adobe" }
            elseif ($name -match '(?i)(DAEMON|K-Lite|Dolby\s+Audio)') { $cat = "Media / Codecs" }
            elseif ($name -match '(?i)(Google\s+Chrome|Microsoft\s+Edge|Yandex)') { $cat = "Browsers" }
            elseif ($name -match '(?i)(Node\.js|Git|curl|WinRAR|Far\s+Manager|VSCodium|Pandoc)') { $cat = "Dev Tools (keep)" }

            if ($cat -eq "Other") {
                $unk += "$name | $pub | ${size}MB"
            } else {
                if (-not $grouped[$cat]) { $grouped[$cat] = @() }
                $grouped[$cat] += "$name | ${size}MB"
            }
        }

        Write-Host "`n=== SOFTWARE INVENTORY BY CATEGORY ===`n"
        foreach ($cat in ($grouped.Keys | Sort-Object)) {
            Write-Host "`n--- $cat ---"
            $grouped[$cat] | ForEach-Object { Write-Host "  $_" }
        }
        Write-Host "`n--- Uncategorized ---"
        $unk | ForEach-Object { Write-Host "  $_" }
        Write-Host "`n"
    }

    'noise' {
        # Compact view: skip Microsoft redistributables, KB updates, SDK internals
        $items | Where-Object {
            $_.DisplayName -notmatch '(?i)^(Update for|Security Update|Hotfix|KB\d{6,}|Service Pack|Microsoft\s+(Visual\s+C\+\+|\.NET\s+(Framework|Host|Runtime|SDK)|ASP\.NET|Windows\s+Desktop|Update\s+Health|OneDrive|Edge\s+Update))'
        } | Sort-Object DisplayName | ForEach-Object {
            $_.DisplayName -replace '\r?\n', ' '
        }
    }
}
