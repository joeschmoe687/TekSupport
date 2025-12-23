# Samsung S931U (RFCY518ZA0Y) - BLE Testing Guide

> Device: Samsung SM S931U (Galaxy S25 Ultra)  
> OS: Android 16 (API 36)  
> Serial: RFCY518ZA0Y

## Device Status

Check device connection and specs:

```bash
# List connected devices
adb devices
# Expected: RFCY518ZA0Y    device

# Check Android version
adb shell getprop ro.build.version.release
# Expected: 16

# Check model
adb shell getprop ro.product.model
# Expected: SM-S931U

# Check Bluetooth HCI snoop logging status
adb shell getprop persist.bluetooth.hcidump
# Expected: 1 (enabled)
```

## Enable HCI Snoop Logging

1. **Unlock Developer Options:**
   - Open Settings
   - Scroll to "About phone"
   - Tap "Build number" **7 times** (watch for "Developer options enabled" toast)

2. **Enable Bluetooth HCI Snoop Log:**
   - Go back and open "Developer options"
   - Search for "Bluetooth HCI snoop log" or scroll down
   - Toggle **ON**

3. **Verify Enabled:**
   ```bash
   adb shell getprop persist.bluetooth.hcidump
   # Should return: 1
   ```

## Pull HCI Logs

### Quick Pull (Recommended)
```bash
cd hvac_support_app
./scripts/pull_ble_logs.sh s931u --csv
```

### Manual Pull
```bash
mkdir -p docs/BLE-Sniffing/phone-data
adb pull /sdcard/Android/data/com.android.bluetooth/files/btsnoop_hci.log \
  docs/BLE-Sniffing/phone-data/btsnoop_hci_$(date +%Y-%m-%d)_s931u.log
```

## Test Workflow

1. **Enable HCI logging** (see above)

2. **Clear old logs:**
   ```bash
   adb shell rm /sdcard/Android/data/com.android.bluetooth/files/btsnoop_hci.log
   ```

3. **Reproduce test scenario:**
   - Open Testo app → connect T115i/T549i → take measurement
   - OR open Fieldpiece → measure pressure/temperature
   - OR connect ABM-200 → check airflow readings
   - Session should be 5-15 minutes

4. **Pull logs immediately after:**
   ```bash
   ./scripts/pull_ble_logs.sh s931u --csv
   ```

5. **Analyze:**
   ```bash
   # Open CSV in spreadsheet
   open docs/BLE-Sniffing/reports/hci_packets_$(date +%Y-%m-%d)_s931u.csv
   
   # Or inspect raw HCI log with Wireshark
   wireshark docs/BLE-Sniffing/phone-data/btsnoop_hci_$(date +%Y-%m-%d)_s931u.log
   ```

## Troubleshooting

### Device Not Appearing in `adb devices`

**Symptom:** `RFCY518ZA0Y` not listed

**Solutions:**
1. Reconnect USB cable
2. Settings → Developer Options → **USB Debugging** (toggle OFF, then ON)
3. When prompted on device, tap "Allow" to authorize computer
4. Wait 2-3 seconds and run `adb devices` again

### HCI Log Not Generating

**Symptom:** File `/sdcard/Android/data/com.android.bluetooth/files/btsnoop_hci.log` is empty or missing

**Solutions:**
1. Verify enabled: `adb shell getprop persist.bluetooth.hcidump` (should be `1`)
2. Clear old log: `adb shell rm /sdcard/Android/data/com.android.bluetooth/files/btsnoop_hci.log`
3. **Reproduce BLE session for 5+ minutes** (must actively connect/measure)
4. Pull immediately after: `./scripts/pull_ble_logs.sh s931u --csv`

### CSV Export Fails

**Symptom:** `hci_packets_*.csv` file is empty or tshark errors

**Solutions:**
1. Install Wireshark: `brew install wireshark`
2. Verify HCI log exists and has content: `ls -lh docs/BLE-Sniffing/phone-data/*s931u*`
3. Re-run with verbose: `tshark -r docs/BLE-Sniffing/phone-data/btsnoop_hci_*_s931u.log | head -20`

### Bluetooth Keeps Disconnecting During Measurement

**Symptom:** Device connects then drops connection, HCI log shows disconnect packets

**Possible causes:**
- Interference (WiFi 5GHz, microwaves)
- Distance from device (BLE max ~30 feet)
- Device battery low
- S931U in aggressive power saving mode

**Solutions:**
1. Test in clear area without interference
2. Keep device within 10 feet of S931U
3. Ensure test device battery > 50%
4. Disable battery saver: Settings → Battery → Battery Saver (OFF)
5. Disable WiFi during test (if possible)

## Performance Notes

- **HCI log file grows rapidly:** ~1 MB per 10 seconds of active BLE traffic
- **CSV export is slower:** tshark takes 10-30 seconds to parse large HCI logs
- **S931U handles high packet rate well:** Can capture 1000+ packets/second without dropping

## Known Quirks

1. **USB cable matters:** Use USB 3.0+ cable for faster file transfers
2. **HCI logging stops on reboot:** Must re-enable if device restarts
3. **First pull is slow:** ADB caches on subsequent pulls
4. **Date format:** Logs use `YYYY-MM-DD` timestamp to avoid timezone issues

## Storage Info

```bash
# Check S931U storage
adb shell df -h

# Typical free space
# /sdcard: 50-100+ GB available

# HCI logs location uses minimal storage:
# Single 30-min measurement ≈ 300 MB (then compresses to ~50 MB)
```

## Next Steps

1. Enable HCI logging on S931U
2. Run workflow above to capture baseline
3. Compare HCI logs across different:
   - Devices (Testo, Fieldpiece, ABM-200)
   - Locations (office, basement, outdoors)
   - Scenarios (normal measure, heavy interference, distance test)
4. Upload findings to `docs/BLE-Sniffing/reports/`
5. Document protocol analysis in `docs/BLE-Sniffing/[Device-Name]/`

