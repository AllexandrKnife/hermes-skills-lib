# USB Device Enumeration from WSL

Tested on: Windows 10 LTSC (build 19044) from Ubuntu 22.04 WSL2

## Overview

`lsusb` does NOT work in WSL (returns empty, exit code 1). All USB queries must go through PowerShell on the Windows host.

## Tested Queries

### All USB devices with status
```bash
powershell.exe -Command "Get-PnpDevice | Where-Object { \$_.Class -eq 'USB' } | Select-Object Status, FriendlyName"
```

### Only active USB peripherals (skip hubs/controllers)
```bash
powershell.exe -Command "Get-PnpDevice | Where-Object { \$_.Class -eq 'USB' -and \$_.Status -eq 'OK' } | Select-Object FriendlyName"
```

### USB + HID + DiskDrive + Bluetooth
```bash
powershell.exe -Command "Get-PnpDevice | Where-Object { \$_.Class -eq 'USB' -or \$_.Class -eq 'DiskDrive' -or \$_.Class -eq 'HIDClass' -or \$_.Class -eq 'Bluetooth' } | Select-Object Status, Class, FriendlyName"
```

### Clean VID/PID extraction (skips hubs/controllers)
```bash
powershell.exe -Command "Get-CimInstance Win32_PnPEntity | Where-Object { \$_.PNPClass -eq 'USB' -and \$_.Status -eq 'OK' -and \$_.Name -notlike '*Intel*' -and \$_.Name -notlike '*Generic*' -and \$_.Name -notlike '*Root*' -and \$_.Name -notlike '*Hub*' } | Select-Object @{n='VID';e={\$_.DeviceID -replace '.*VID_([0-9A-F]+).*','\$1'}}, @{n='PID';e={\$_.DeviceID -replace '.*PID_([0-9A-F]+).*','\$1'}}, Description"
```

### All USB via WMI (includes hubs)
```bash
powershell.exe -Command "Get-CimInstance Win32_USBControllerDevice | ForEach-Object { \$dep = [System.String]\$_.Dependent ; Write-Output \$dep }"
```

### USB storage drives
```bash
powershell.exe -Command "Get-CimInstance Win32_DiskDrive | Where-Object { \$_.InterfaceType -eq 'USB' } | Select-Object Model, Size, MediaType"
```

### All disk drives with interface type
```bash
powershell.exe -Command "Get-CimInstance Win32_DiskDrive | Select-Object Model, @{n='GB';e={\$_.Size/1GB -as [int]}}, InterfaceType, MediaType | Format-Table -AutoSize"
```

### Force English output (bypass locale garbling)
```bash
powershell.exe -Command "\$culture = [System.Globalization.CultureInfo]::CreateSpecificCulture('en-US'); [System.Threading.Thread]::CurrentThread.CurrentUICulture = \$culture; Get-PnpDevice | Where-Object { \$_.Class -eq 'USB' } | Select-Object Status, FriendlyName"
```

## VID/PID Vendor Lookups

| Service | URL | Notes |
|---------|-----|-------|
| macvendors.com | `curl -s "https://api.macvendors.com/046D"` | Returns vendor name (also works for USB VID) |
| USB ID database | `curl -s "https://usb-ids.garrettflux.com/id/046D"` | USB-specific ID database |
| devicehunt.com | `curl -s "https://devicehunt.com/view/type/usb/vendor/046D"` | Detailed info including PID listings |

## Known Device IDs on Test Machine (HP Desktop/Laptop)

| VID | PID | Device | Notes |
|-----|-----|--------|-------|
| `046D` | `C534` | Logitech Unifying Receiver | Keyboard/mouse combo |
| `05C8` | `0369` | HP Webcam / Chicony | Built-in laptop webcam |
| `0A5C` | `21F1` | Broadcom Bluetooth 4.0 | Internal adapter |
| `0951` | `1643` | Kingston DataTraveler G3 | USB flash drive (unplugged = Unknown status) |
| `2717` | `FF48` | Xiaomi phone | When connected via USB cable |
| `8087` | `8000` | Intel USB 2.0 Hub (EHCI) | Chipset internal |
| `8087` | `8008` | Intel USB 2.0 Hub (EHCI) | Chipset internal |

## Encoding Notes

- Russian locale causes garbled `FriendlyName`/`Description` strings when output to terminal via PowerShell
- The `DeviceID` field always contains clean VID_XXXX&PID_XXXX — use this for identification
- Setting UI culture to en-US via `[System.Globalization.CultureInfo]` works but not perfectly for all fields
- Best approach: extract VID/PID from `DeviceID`, then look up vendor name via web API
