# WiFi Diagnostics from WSL — Commands & Interpretation

## Quick one-liner matrix

| What you need | Command | Key fields |
|---|---|---|
| Current connection | `netsh wlan show interfaces` | SSID, BSSID, Radio type, Channel, Receive/Transmit speed (Mbps), Signal (%) |
| Adapter model & driver | `netsh wlan show drivers` | Driver (vendor, date, version), supported 802.11 types |
| Saved networks | `netsh wlan show profiles` | Profile names (SSIDs with saved creds) |
| Visible networks | `netsh wlan show networks mode=Bssid` | All BSSIDs per SSID, band (from channel), signal per BSSID |
| Adapter advanced settings | `Get-NetAdapterAdvancedProperty` | BandwidthCapability, Disable Bands, ShortGI, 40MHz Intolerant |
| Router ARP table | `Get-NetNeighbor -AddressFamily IPv4` | IP → MAC mappings on Windows host |

## Example: full diagnostic script

Save as `/mnt/c/Users/Public/wifi_diag.ps1` and run with:
```bash
powershell.exe -File "C:\Users\Public\wifi_diag.ps1"
```

```powershell
Write-Host "=== Wi-Fi Interface ==="
netsh wlan show interfaces | Out-String

Write-Host "=== Driver ==="
netsh wlan show drivers | Out-String

Write-Host "=== Adapter Advanced Settings (key parameters) ==="
Get-NetAdapter -InterfaceDescription "*" | Where-Object { $_.Name -match "Wi-Fi|Wireless|WLAN" } |
  Get-NetAdapterAdvancedProperty | Where-Object {
    $_.RegistryKeyword -match "Bandwidth|Band|Intolerant|ShortGI|Power|802"
  } | Format-Table Name, DisplayName, DisplayValue -AutoSize

Write-Host "=== All Adapter Advanced Settings (full dump) ==="
Get-NetAdapter -InterfaceDescription "*" | Where-Object { $_.Name -match "Wi-Fi|Wireless|WLAN" } |
  Get-NetAdapterAdvancedProperty | Format-Table Name, DisplayName, DisplayValue -AutoSize

Write-Host "=== BandwidthCap Registry Options ==="
$regBase = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\0002\Ndi\params\BandwidthCap\enum"
if (Test-Path $regBase) {
  Get-ChildItem $regBase | ForEach-Object {
    $val = $_.PSChildName
    $desc = (Get-ItemProperty -Path $_.PSPath).PSChildName
    Write-Host "  Value $val = $desc"
  }
}

Write-Host "=== Visible Networks ==="
netsh wlan show networks mode=Bssid | Out-String

Write-Host "=== Power Management ==="
Get-NetAdapter -Name "*Wi-Fi*","*Wireless*","*WLAN*" | Get-NetAdapterPowerManagement | Format-List
```

## How to interpret the results

### Band identification
If the output shows `802.11n` and Channel is 1-13 → it's on **2.4 GHz** (max ~144-300 Mbps).
If it shows `802.11a`, `802.11ac`, `802.11ax`, or Channel >13 → it's on **5 GHz** (much faster).

### Link speed meaning
On 802.11n with a 2×2 adapter (two spatial streams):

| Channel width | Link speed | Real throughput (est.) |
|---|---|---|
| 20 MHz | 144 Mbps | ~40-70 Mbps |
| 40 MHz (HT40) | 300 Mbps | ~100-170 Mbps |

Comparison across standards:
- **2.4 GHz 802.11n 20 MHz 2SS** → 144 Mbps
- **2.4 GHz 802.11n 40 MHz 2SS** → 300 Mbps
- **5 GHz 802.11ac 80 MHz 1SS** → 433 Mbps
- **5 GHz 802.11ac 80 MHz 2SS** → 867 Mbps
- **5 GHz 802.11ax 80 MHz 1SS** → 600 Mbps
- **5 GHz 802.11ax 160 MHz 2SS** → 2400 Mbps

Real-world throughput is typically 40-60% of link speed due to protocol overhead, interference, and retransmissions.

**Key diagnostic shortcut**: If user reports laptop is 3× slower than phone on the same 2.4 GHz router, the phone's WiFi chip (WiFi 5/6) has better sensitivity, higher modulation (256/1024-QAM vs 64-QAM), and often better MIMO. The adapter's link speed is the first thing to check — 144 Mbps means it's capped at 20 MHz channel width. Doubling to 300 Mbps (HT40) is the biggest single improvement available on 2.4 GHz 802.11n.

### Channel congestion
- 2.4 GHz channels 1, 6, 11 are the only non-overlapping ones. Being on channel 3 means overlapping with both 1 and 6 — bad.
- `netsh wlan show networks mode=Bssid` shows ALL visible APs per channel → count how many on your channel.

### Driver age
Driver date >3 years old = outdated. Check manufacturer's site for latest.
For Broadcom BCM943228HMB: last driver was ~2018. The adapter itself is obsolete (802.11n only).

### Common laptop WiFi slowness patterns

| Symptom | Likely cause | Fix |
|---|---|---|
| Phone fast, laptop slow | Laptop on 2.4 GHz, phone on 5 GHz | Connect laptop to 5 GHz |
| Both slow on same network | Router channel congestion | Change 2.4 GHz channel to 1/6/11, enable HT40 |
| Speed drops periodically | Bluetooth interference (2.4 GHz band sharing), or USB 3.0 noise | Disable BT when using WiFi, move USB 3 devices away |
| Signal 80%+ but speed poor | Adjacent-channel interference or tx power limits | Check `Power Output` in advanced adapter settings (should be 100%) |
| Laptop 3× slower than phone on same 2.4 GHz router | Laptop adapter is old 802.11n (144 Mbps cap), phone has modern WiFi 5/6 with better modulation | Enable HT40 on router, or replace adapter with WiFi 5/6 |
| Link speed stuck at 144 Mbps on Broadcom adapter | BandwidthCap=2 restricts 2.4 GHz to 20 MHz | Change to BandwidthCap=1 (see Broadcom tweaks below) |

### Router side check
If user has a Keenetic router (BSSID OUI `50:ff:20`), the typical dual-band SSID scheme is:
- `Keenetic-XXXX` → 2.4 GHz band
- `Keenetic-XXXX-5` → 5 GHz band

The user's SSID `Keenetic-V` is likely the 2.4 GHz only. Look for `Keenetic-V-5` or similar in the scan, or check router admin page.

## Broadcom adapter tweaking: enabling 40 MHz on 2.4 GHz

Many Broadcom adapters (e.g. BCM943228HMB) ship with **BandwidthCap = 2** which restricts 2.4 GHz to 20 MHz even if the radio supports 40 MHz. This caps link speed at 144 Mbps.

### BandwidthCap registry values

Find at `HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\<instance>\Ndi\params\BandwidthCap`

| Value | Meaning | Link speed (2.4 GHz 2×2) |
|---|---|---|
| 0 | 20 MHz only on both bands | 144 Mbps |
| 1 | 20/40 MHz on **both** 2.4 GHz and 5 GHz | **300 Mbps** ← try this |
| 2 | 20/40 on 5 GHz only, 20 on 2.4 GHz (default) | 144 Mbps |

### How to change (PowerShell)

```powershell
# Check current value
Get-NetAdapterAdvancedProperty -InterfaceDescription "*Broadcom*" -RegistryKeyword "BandwidthCap"

# Set to "1" (20/40 on both bands)
Set-NetAdapterAdvancedProperty -InterfaceDescription "*Broadcom*" -RegistryKeyword "BandwidthCap" -RegistryValue 1

# Reconnect WiFi for the change to take effect
netsh wlan disconnect
netsh wlan connect ssid=Keenetic-V name=Keenetic-V
```

Or via registry directly:
```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\0002" -Name "BandwidthCap" -Value 1
```

**Note**: After changing, verify link speed with `netsh wlan show interfaces`. It should jump from 144 → 300 Mbps. If stability issues occur, revert to 2.

### Other useful Broadcom advanced settings

| Setting | RegistryKeyword | Recommended value |
|---|---|---|
| Disable Bands | `band` | 0 (None — both bands enabled) |
| Band Preference | `BandPref` | 0 (None — let adapter choose best) |
| Short GI | `ShortGI` | -1 (Auto — enables shorter guard interval for ~10% speed gain) |
| 40MHz Intolerant | `Intolerant` | 0 (Disabled — allows 40 MHz channel) |
| 20/40 Coexistence | `OBSSCoex` | -1 (Auto) |
| Power Output | `PwrOut` | 100 (100% — never lower this) |

## Speed testing from WSL — known limitations

When the user asks to measure real WiFi throughput from WSL:

| Method | Works? | Notes |
|---|---|---|
| `ping 8.8.8.8` | Usually yes | Tests connectivity but not throughput |
| `curl http://speedtest.tele2.net/10MB.zip` | Sometimes | May fail from WSL's NAT'd network |
| PowerShell `WebClient.DownloadData()` | Sometimes | Can fail with "Network is unreachable" even when ping works |
| `curl` from Windows (`powershell.exe -Command "curl.exe ..."`) | Sometimes | Can timeout on larger files |
| Browser to fast.com / speedtest.net | **Yes** | Best option — just ask user to test in browser |
| `Test-Connection 8.8.8.8` from PowerShell | Usually yes | ICMP-based |

**Bottom line**: From WSL, link speed (`netsh wlan show interfaces` → Receive/Transmit speed) is the most reliable metric. For real TCP throughput, ask the user to open fast.com or speedtest.net in their browser — WSL's virtual NIC adds its own bottleneck and makes results unreliable.

The link speed to real-throughput conversion factor on 2.4 GHz 802.11n is roughly **35-50%**:
- 144 Mbps link → ~40-70 Mbps real
- 300 Mbps link → ~100-170 Mbps real
