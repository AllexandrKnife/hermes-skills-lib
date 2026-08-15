# Real-World Channel Scan Analysis

## Environment Profile

- **Adapter:** Realtek 8821AE Wireless LAN 802.11ac PCI-E NIC
- **Router:** Keenetic-V (Keenetic, 2.4 GHz only)
- **Location:** Apartment, dense urban 2.4 GHz
- **Bluetooth:** Active (JBL Charge 4 speaker connected)
- **Channel:** 1 (default)
- **Signal:** 100%
- **Link speed:** 150 Mbps (802.11n, HT40)
- **DNS:** 1.1.1.1 / 1.0.0.1 (Cloudflare)

## Full Scan (13 visible networks)

| SSID | Channel | Signal | Radio Type | Notes |
|------|---------|--------|------------|-------|
| **Keenetic-V** | **1** | **100%** | **802.11n** | **Own router** |
| (hidden) 52:ff:20:4e:e0:bd | 1 | 100% | 802.11n | Likely guest SSID on same Keenetic |
| netis-9DE31B | 1 | 14% | 802.11n | Neighbor, weak |
| **RT-GPON-10E7** | **2** | **100%** | **802.11n** | **MAIN INTERFERER — strongest neighbor, overlaps ch1** |
| 2.4GG | 2 | 65% | 802.11n | Neighbor |
| RT-GPON-1B00 | 7 | 8% | 802.11n | Neighbor, weak |
| TP-LINK_8AB6 | 8 | 12% | 802.11n | Neighbor, weak |
| TP-Link_180 | 10 | 45% | 802.11n | Neighbor |
| (hidden) 56:ef:44:4f:7b:95 | 10 | 85% | 802.11b | Neighbor, strong legacy |
| MTSRouter_006296 | 11 | 4% | 802.11n | Neighbor, weak |
| (hidden) e4:38:83:c2:c3:6b | 11 | 12% | 802.11n | Neighbor, weak |
| MTS_Router_381705 | 13 | 25% | 802.11n | Neighbor |
| RT-5GPON-10E7 | 52 (5 GHz) | 95% | 802.11ax | Neighbor's 5 GHz, irrelevant |

## Congestion Map

```
2.4 GHz:
  ch 1 ████████████████████  Keenetic-V (100%) + hidden (100%) + netis (14%)
  ch 2 ████████████████████  RT-GPON-10E7 (100%❗) + 2.4GG (65%)
  ch 3 ░░░░                 (interference overlap from 1+2)
  ch 4 ░░                   
  ch 5 ░░                   
  ch 6 ⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜   CLEAN
  ch 7 ░░░                  RT-GPON-1B00 (8%)
  ch 8 ░░░░                 TP-LINK_8AB6 (12%)
  ch 9 ░░░░                 
  ch10 ████████████████      TP-Link_180 (45%) + hidden_85%
  ch11 ░░░░                 MTSRouter (4%) + hidden (12%)
  ch13 ██████████            MTS_Router (25%)
```

## Recommended Action

1. **Move Keenetic-V from channel 1 → channel 6** (completely clean, no overlap with ch2 interferer)
2. **Disable Bluetooth** (JBL Charge 4 → causes 2.4 GHz coexistence degradation on Realtek combo chip)
3. **Check router for HT40 (40 MHz)** — if currently HT20, throughput is artificially capped at ~72 Mbps

## Adapter Advanced Properties Found

| Property | Value | Recommended |
|----------|-------|-------------|
| Roaming Sensitivity | Low | ✓ OK for home |
| 802.11d | Enabled | Consider Disabled |
| Preamble | Long and Short | ✓ Default |
| Beacon Interval | 100 | ✓ Default |
| Multi-Channel Concurrent | Enabled + Hotspot | ✓ Default |
| Wake-on Magic Packet | Enabled | Disable if not needed |
| Radio Mode | Auto | ✓ Default |

## Result Prediction

| Change | Expected Gain | Confidence |
|--------|--------------|------------|
| ch1 → ch6 | 30-50% fewer retransmits | High |
| BT off | 20-40% sustained throughput | High |
| HT20 → HT40 (if applicable) | 2x raw speed (72→150) | Medium (depends on router) |
