# 4-Sensor Live Test Plan - Testo + Fieldpiece

## Objective
Build fresh superheat/subcool chart using simultaneous readings from 4 sensors (2 manufacturers) to verify BLE parsing accuracy and cross-validate pressure/temperature data.

## Equipment

### Testo Smart Probes (BLE Connectable)
1. **T549i** - High-side pressure clamp
   - Expected: 60-80 psig
   - Current Status: ❌ BROKEN (shows 0.6 vs 71 psi)
   - Service: `fff0`, Notify: `fff2`

2. **T115i** - Temperature clamp  
   - Expected: Accurate readings
   - Current Status: ✅ WORKING (47.6°F accurate)
   - Service: `fff0`, Notify: `fff2`

### Fieldpiece Probes (BLE Broadcast Only)
3. **Pressure Gauge** - High-side pressure
   - Type: Non-connectable advertisements
   - Manufacturer ID: `0x5046` ("FP")
   - Current Status: ✅ WORKING (broadcast parsing verified)

4. **Temperature Clamp** - Line temperature
   - Type: Non-connectable advertisements
   - Manufacturer ID: `0x5046` ("FP")
   - Current Status: ✅ WORKING (broadcast parsing verified)

## Test Setup

### Pre-Test Checklist
- [ ] All 4 sensors have fresh batteries
- [ ] Testo probes paired/saved in app
- [ ] BLE scan enabled for Fieldpiece broadcast
- [ ] HCI snoop logging enabled on device
- [ ] Terminal ready for log capture
- [ ] HVAC system running and stable

### Android Device Setup
```bash
# Enable HCI snoop logging (capture BLE packets)
adb shell settings put global bluetooth_hci_log 1
adb shell setprop persist.bluetooth.btsnoopenable true

# Restart Bluetooth to activate logging
adb shell svc bluetooth disable && sleep 2 && adb shell svc bluetooth enable

# Clear app data for fresh start
adb shell pm clear com.tekneckjoe.tektool
```

### Launch App with Logging
```bash
# Navigate to project
cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app

# Launch with full log capture
/Users/joeykeilbarth/flutter/bin/flutter run --device-id=RFCY518ZA0Y 2>&1 | tee logs/4sensor_test_$(date +%Y%m%d_%H%M%S).log
```

### Separate Terminal for Filtered Logs
```bash
# Monitor pressure parsing in real-time
adb logcat | grep "\[Pressure\]" | tee logs/pressure_debug_$(date +%Y%m%d_%H%M%S).log

# Or monitor all device data
adb logcat | grep -E "\[Pressure\]|\[Temperature\]|\[Fieldpiece\]"
```

## Test Procedure

### Phase 1: Connection (5 minutes)
1. Open app → Navigate to Tools Hub
2. Connect Testo T549i (pressure)
3. Connect Testo T115i (temp)
4. Start BLE scan for Fieldpiece devices
5. Verify all 4 sensors showing data in app
6. Screenshot: Home screen with all devices connected

**Expected Results:**
- Testo devices show "Connected" with green indicator
- Fieldpiece devices appear in scan results
- Real-time data streaming for all sensors

### Phase 2: Baseline Readings (10 minutes)
Record readings every 30 seconds for 10 minutes:

| Time | Testo Pressure (app) | Testo Pressure (device) | Fieldpiece Pressure | Testo Temp (app) | Testo Temp (device) | Fieldpiece Temp |
|------|---------------------|------------------------|---------------------|-----------------|--------------------|-----------------| 
| 0:00 | | | | | | |
| 0:30 | | | | | | |
| 1:00 | | | | | | |
| 1:30 | | | | | | |
| ... | | | | | | |

**Key Metrics to Track:**
- Does Testo pressure match device display?
- Do Testo and Fieldpiece pressures match each other?
- Temperature readings consistent across sensors?
- Any drift or instability over time?

### Phase 3: P/T Chart Validation (15 minutes)
Using captured data, calculate:

#### High Side Measurements
- **Pressure (measured):** ___ psig
- **Saturation temp (from chart):** ___ °F
- **Liquid line temp (measured):** ___ °F
- **Subcool:** Tsat - Tliquid = ___ °F

#### Low Side Measurements  
- **Pressure (measured):** ___ psig
- **Saturation temp (from chart):** ___ °F
- **Suction line temp (measured):** ___ °F
- **Superheat:** Tsuction - Tsat = ___ °F

#### Cross-Validation
- [ ] Testo pressure ± 2 psi of Fieldpiece
- [ ] Testo temp ± 1°F of Fieldpiece
- [ ] Superheat in normal range (8-12°F for TXV)
- [ ] Subcool in normal range (10-15°F)

### Phase 4: Log Analysis
```bash
# Capture bugreport with HCI logs
adb bugreport logs/bugreport_4sensor_$(date +%Y%m%d_%H%M%S).zip

# Extract btsnoop
cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app
unzip -j logs/bugreport_4sensor_*.zip "FS/data/log/bt/btsnoop_hci.log" -d logs/hci/

# Analyze Testo pressure packets
tail -c 500000 logs/hci/btsnoop_hci.log | xxd -c 24 -g 1 | grep -A 1 '74 69 61 6c 50 72 65 73 73' | tee logs/testo_pressure_packets.txt

# Count packet types
echo "Testo packets:"
grep -c '74 69 61 6c' logs/hci/btsnoop_hci.log

echo "Fieldpiece packets:"
xxd logs/hci/btsnoop_hci.log | grep -c '50 46'
```

## Expected Outcomes

### ✅ Success Criteria
1. All 4 sensors streaming data continuously
2. Testo pressure matches device display (±1 psi)
3. Testo temp matches device display (±0.5°F)
4. Testo and Fieldpiece readings agree (±2 psi, ±1°F)
5. Calculated S/H and S/C in normal ranges
6. No BLE disconnections or gaps in data

### ❌ Known Issues to Verify
1. **Testo T549i pressure parsing**
   - Current: Shows 0.6 psi 
   - Expected: ~71 psi
   - Btsnoop shows correct encoding (Uint16/10)
   - Need to identify why parser fails

2. **Fieldpiece broadcast limitations**
   - Cannot connect (non-connectable ADV)
   - Rely on advertisement data only
   - Update rate may be slower

## Data Analysis

### Pressure Value Decoding (Testo)
From btsnoop, find packets starting with `74 69 61 6c 50 72 65 73 73 75 72 65`:

```python
# Example packet analysis
packet_hex = "7469616c507265737375726590e2f148000084c0"
value_bytes = packet_hex[36:40]  # Bytes 18-19 (hex chars 36-40)
# 84 c0 = 0xC084 (LE) = 49284
# 49284 / 10 = 4928.4 mbar
# 4928.4 * 0.0145038 = 71.48 psi
```

### Debug Log Patterns to Check
```
[Pressure] Full packet: 7469616c507265737375726590e2f148000084c0
[Pressure] offset 18 Uint16/10: 49284 -> 4928.4 mbar (71.48 psi)
[Pressure] ✓ Using Uint16/10 at offset 18 (btsnoop confirmed)
```

If these logs DON'T appear:
- Parser not being called
- Pattern matching failing
- Packet format different

### Compare App vs Device
Create comparison chart:

| Sensor | Metric | App Reading | Device Reading | Delta | Status |
|--------|--------|-------------|----------------|-------|--------|
| Testo T549i | Pressure | 0.6 psi | 71 psi | -70.4 psi | ❌ FAIL |
| Testo T115i | Temp | 47.6°F | 47.5°F | +0.1°F | ✅ PASS |
| Fieldpiece | Pressure | ___ psi | ___ psi | ___ psi | ___ |
| Fieldpiece | Temp | ___ °F | ___ °F | ___ °F | ___ |

## Troubleshooting

### If Testo Pressure Still Wrong

#### Option 1: Add Verbose Logging
```dart
// In device_registry.dart _parseTestoPressure()
debugPrint('[Pressure] === PACKET RECEIVED ===');
debugPrint('[Pressure] Length: ${rawData.length}');
debugPrint('[Pressure] Full hex: ${bytesToHex(rawData)}');
debugPrint('[Pressure] First 12 bytes: ${bytesToHex(rawData.take(12).toList())}');
debugPrint('[Pressure] Pattern match: ${_matchesPattern(rawData, 0, tialPressurePattern)}');

if (rawData.length >= 20) {
  debugPrint('[Pressure] Bytes 18-19: ${bytesToHex(rawData.sublist(18, 20))}');
  final bytes = Uint8List.fromList(rawData.sublist(18, 20));
  final byteData = ByteData.view(bytes.buffer);
  final rawUint16 = byteData.getUint16(0, Endian.little);
  debugPrint('[Pressure] Uint16 LE value: $rawUint16');
  debugPrint('[Pressure] Divided by 10: ${rawUint16 / 10.0} mbar');
  debugPrint('[Pressure] In PSI: ${(rawUint16 / 10.0) * 0.0145038} psi');
} else {
  debugPrint('[Pressure] Packet too short for offset 18 read');
}
```

#### Option 2: Try Different Offsets
```dart
// Test all possible 2-byte positions
for (int offset = 12; offset < rawData.length - 1; offset++) {
  final bytes = Uint8List.fromList(rawData.sublist(offset, offset + 2));
  final byteData = ByteData.view(bytes.buffer);
  final value = byteData.getUint16(0, Endian.little);
  final mbar = value / 10.0;
  final psi = mbar * 0.0145038;
  if (psi > 60 && psi < 90) {
    debugPrint('[Pressure] FOUND at offset $offset: $value -> $mbar mbar -> $psi psi');
  }
}
```

#### Option 3: Raw Byte Inspection
```dart
// Print each byte position
for (int i = 0; i < rawData.length && i < 25; i++) {
  debugPrint('[Pressure] Byte $i: 0x${rawData[i].toRadixString(16).padLeft(2, '0')} (${rawData[i]})');
}
```

### If BLE Disconnects
```bash
# Check connection stability
adb logcat | grep -E "BluetoothGatt|FBP"

# Verify RSSI signal strength
# In app: Should show RSSI > -80 dBm for stable connection
```

### If Fieldpiece Not Appearing
```bash
# Verify broadcast scanning active
adb logcat | grep "Fieldpiece"

# Check for manufacturer data
adb logcat | grep "0x5046"

# Ensure location permission granted
adb shell dumpsys package com.tekneckjoe.tektool | grep -A 5 "permissions"
```

## Post-Test Actions

### Files to Save
- [ ] `logs/4sensor_test_YYYYMMDD_HHMMSS.log` - Full Flutter log
- [ ] `logs/pressure_debug_YYYYMMDD_HHMMSS.log` - Filtered pressure logs
- [ ] `logs/bugreport_4sensor_YYYYMMDD_HHMMSS.zip` - Android bugreport
- [ ] `logs/hci/btsnoop_hci.log` - BLE packet capture
- [ ] `logs/testo_pressure_packets.txt` - Extracted pressure packets
- [ ] Screenshots of app during test
- [ ] Photos of physical device displays

### Analysis Deliverables
1. **Comparison table** - App vs device readings
2. **P/T chart** - Calculated S/H and S/C
3. **Packet analysis** - Hex dump of problematic packets
4. **Timeline** - When issues occurred
5. **Recommendations** - Next debugging steps

### Share with Next Session
```
Summary for next AI session:
- Test date/time: ___
- Testo pressure: Still wrong (0.6 vs ___ psi actual)
- Root cause: ___
- Btsnoop findings: ___
- Recommended fix: ___
```

## Quick Reference

### Device IDs
- **Android Device:** RFCY518ZA0Y (Samsung SM S931U)
- **Testo T549i:** [MAC address from scan]
- **Testo T115i:** [MAC address from scan]
- **Fieldpiece:** Non-connectable broadcast

### Service UUIDs
- **Testo:** `0000fff0-0000-1000-8000-00805f9b34fb`
- **Fieldpiece:** N/A (broadcast only)

### File Locations
- **Parser:** `lib/tools/services/device_registry.dart`
- **Data Service:** `lib/tools/services/device_data_service.dart`
- **P/T Chart:** `lib/tools/utils/pt_chart.dart`
- **Logs:** `logs/`
- **Docs:** `docs/`

---

**Test Date:** [To be filled during test]  
**Tester:** [Your name]  
**Duration:** ~30 minutes  
**Status:** Ready to execute
