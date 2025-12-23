# Testo T549i Pressure Debugging Session - Dec 22, 2025

## Current Status: STILL BROKEN ❌

**Problem:** App shows 0-0.6 psig while Testo device displays ~71 psig

## Attempts Made

### Attempt 1: Multi-offset Float32 heuristics
- **Date:** Dec 22, 2025 (early session)
- **Change:** Added multiple Float32 offset attempts with heuristics
- **Result:** Still showing 0.00 psi ❌

### Attempt 2: Int32 at offset 18 with ÷10
- **Date:** Dec 22, 2025 (mid session)
- **Based on:** Offline btsnoop analysis showing 24-byte packets
- **Change:** Read Int32 LE at offset 18, divide by 10
- **Result:** Code never executed - live packets are 20 bytes, not 24 ❌

### Attempt 3: Int16 at offset 18 with ÷10
- **Date:** Dec 22, 2025 (mid session)
- **Based on:** Live app logs showing 20-byte packets
- **Change:** Read Int16 LE at offset 18, divide by 10
- **Result:** Still showing 0-0.6 psi ❌

### Attempt 4: Uint16 at offset 18 with ÷10 (CURRENT)
- **Date:** Dec 22, 2025 22:30 (latest attempt)
- **Based on:** Fresh btsnoop analysis showing unsigned values
- **Btsnoop Analysis:**
  ```
  Packet: 74 69 61 6c 50 72 65 73 73 75 72 65 90 e2 f1 48 00 00 84 c0
          t  i  a  l  P  r  e  s  s  u  r  e  [timestamp]     [value]
  
  Value at offset 18-19: 84 c0
  - As signed Int16 LE:   -16252 → -1625.2 mbar → -23.57 psi ❌
  - As unsigned Uint16 LE: 49284 → 4928.4 mbar → 71.48 psi ✓
  ```
- **Change:** `getInt16()` → `getUint16()` in `device_registry.dart`
- **Expected:** Should decode 71 psi correctly based on btsnoop math
- **Result:** Still showing 0-0.6 psi ❌
- **Status:** NEEDS INVESTIGATION - Math is correct but app still broken

## Packet Structure (Confirmed via btsnoop)

```
Byte Offset | Content              | Example Hex
------------|----------------------|-------------
0-11        | ASCII "tialPressure" | 74 69 61 6c 50 72 65 73 73 75 72 65
12-15       | Timestamp (4 bytes)  | 90 e2 f1 48
16-17       | Padding (always 0)   | 00 00
18-19       | Uint16 LE (mbar×10)  | 84 c0
```

**Total packet length:** 20 bytes

**Decoding:**
1. Find "tialPressure" at start of packet
2. Extract bytes 18-19 as Uint16 LE
3. Divide by 10 to get mbar
4. Multiply by 0.0145038 to get psi

**Example:** `84 c0` = 0xC084 = 49284 → 4928.4 mbar → 71.48 psi

## Files Modified

### `lib/tools/services/device_registry.dart`
**Function:** `_parseTestoPressure()`
**Line:** ~601
**Current code:**
```dart
final rawUint16 = byteData.getUint16(0, Endian.little);  // UNSIGNED!
final mbarFromInt = rawUint16 / 10.0;
```

## Possible Issues to Investigate

### 1. Parser Not Being Called
- Check if "tialPressure" pattern matching is working
- Verify packet length check (>= 20 bytes)
- Check if valid range check is failing (0 to 50000 mbar)

### 2. Different Packet Format When App Connected
- Offline btsnoop may differ from live app packets
- MTU fragmentation could split packets differently
- ATT overhead may affect byte positions

### 3. Value Encoding Differs
- Maybe divisor should be ÷100 instead of ÷10?
- Maybe value is at different offset?
- Maybe byte order is wrong?

### 4. Debug Logs Not Showing
- Check if debug prints are being filtered
- Verify parser is receiving data at all

## Next Steps for Debugging

### Option A: Add More Debug Logging
```dart
debugPrint('[Pressure] Raw packet length: ${rawData.length}');
debugPrint('[Pressure] First 20 bytes: ${bytesToHex(rawData.take(20).toList())}');
debugPrint('[Pressure] Pattern match: ${_matchesPattern(rawData, 0, tialPressurePattern)}');
debugPrint('[Pressure] Bytes 18-19: ${rawData.length >= 20 ? bytesToHex(rawData.sublist(18, 20)) : "too short"}');
```

### Option B: Capture Live Logs During Test
```bash
# During 'flutter run', filter for pressure logs
adb logcat | grep "\[Pressure\]" > pressure_debug.log

# Or capture all Flutter logs
flutter run --device-id=RFCY518ZA0Y 2>&1 | tee flutter_test.log
```

### Option C: Use BLE Sniffer Screen in App
- Navigate to Tools → BLE Sniffer (admin only)
- Connect to T549i
- Capture packets in real-time
- Packets auto-upload to Firebase `ble_sniff_logs` collection
- Analyze raw packets to verify byte structure

## Comprehensive 4-Sensor Test Plan

### Equipment Setup
1. **Testo T549i** - High pressure clamp
2. **Testo T115i** - Temperature clamp  
3. **Fieldpiece (pressure)** - High pressure gauge
4. **Fieldpiece (temp)** - Temperature clamp

### Test Objectives
- Capture live BLE data from all 4 sensors simultaneously
- Build fresh P/T chart with superheat/subcool calculations
- Verify both manufacturers' readings match
- Compare app readings to device displays
- Document any discrepancies

### Data to Capture
- High side pressure (psig)
- Low side pressure (psig)
- Suction line temperature (°F)
- Liquid line temperature (°F)
- Saturation temperatures (from P/T chart)
- Calculated superheat
- Calculated subcool

### Test Procedure
1. Connect all 4 sensors to app
2. Verify all devices streaming data
3. Monitor app displays for 5 minutes
4. Record readings every 30 seconds
5. Compare app values to device displays
6. Capture logs: `flutter run | tee 4sensor_test.log`
7. Capture btsnoop if issues found

### Expected Results
- **Temperature readings:** Should match exactly (proven working)
- **Fieldpiece readings:** Broadcast-only, should show in scan
- **Testo T115i temp:** Already working (47.6°F accurate)
- **Testo T549i pressure:** BROKEN (0.6 vs 71 psi) - needs fix

## Files for Next Session

### Code Files
- `lib/tools/services/device_registry.dart` - Testo pressure parser
- `lib/tools/services/device_data_service.dart` - BLE data streaming
- `lib/tools/utils/pt_chart.dart` - P/T calculations

### Log Files
- `logs/hci/btsnoop_hci.log` - Latest BLE capture (from bugreport_fresh_20251222_223135.zip)
- `pressure_debug.log` - To be created during next test
- `4sensor_test.log` - To be created during comprehensive test

### Documentation
- `docs/DEVELOPMENT_WORKFLOW.md` - Launch commands and workflow
- `docs/TESTO_PRESSURE_DEBUGGING_SESSION.md` - This file
- `test/README.md` - Testing guide

## Quick Commands for Next Session

### Launch App
```bash
cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app
/Users/joeykeilbarth/flutter/bin/flutter run --device-id=RFCY518ZA0Y
```

### Monitor Logs
```bash
# In separate terminal
adb logcat | grep "\[Pressure\]"
```

### Capture Fresh Btsnoop
```bash
# Enable HCI logging (if not already enabled)
adb shell settings put global bluetooth_hci_log 1

# After test, pull bugreport
adb bugreport bugreport_4sensor_$(date +%Y%m%d_%H%M%S).zip

# Extract btsnoop
unzip -j bugreport_*.zip "FS/data/log/bt/btsnoop_hci.log" -d logs/hci/

# Search for Testo packets
tail -c 500000 logs/hci/btsnoop_hci.log | xxd -c 24 -g 1 | grep -A 1 '74 69 61 6c 50 72 65 73 73'
```

## Known Working Components

### ✅ Testo Temperature (T115i)
- Service UUID: `fff0`
- Characteristic: `fff2` (notify)
- Format: Float32 at various offsets
- Status: **WORKING** - Shows 47.6°F accurately

### ✅ Fieldpiece Broadcast
- Manufacturer ID: `0x5046` ("FP")
- Type: Non-connectable advertisements
- Format: Manufacturer data parsing
- Status: **WORKING** - Broadcast data parsed correctly

### ❌ Testo Pressure (T549i)
- Service UUID: `fff0`  
- Characteristic: `fff2` (notify)
- Format: Uint16 at offset 18-19, divide by 10, convert to psi
- Status: **BROKEN** - Shows 0.6 psi instead of 71 psi
- Math verified correct via btsnoop analysis
- Unknown why app still shows wrong value

## Questions to Answer

1. **Why does btsnoop show correct values but app doesn't?**
   - Btsnoop: `84 c0` = 49284 → 4928.4 mbar → 71.48 psi ✓
   - App: Shows 0-0.6 psi ❌

2. **Is the parser even being called?**
   - Need to verify debug logs appear
   - Check if pattern matching succeeds

3. **Are packets arriving intact?**
   - Check packet length in logs
   - Verify "tialPressure" pattern present

4. **Is valid range check too strict?**
   - Currently: `0 to 50000 mbar` (0 to 725 psi)
   - 71 psi = 4896 mbar - should pass

5. **Is there endianness confusion?**
   - Btsnoop confirmed: Little-endian
   - Code uses: `Endian.little` ✓

## Contact Info

**Repository:** [joeschmoe687/hvac_support_app](https://github.com/joeschmoe687/hvac_support_app)  
**Firebase Project:** `tekneck-support`  
**Device ID:** RFCY518ZA0Y (Samsung SM S931U)

---

**Last Updated:** Dec 22, 2025 22:35 PST  
**Status:** Awaiting next test session with comprehensive 4-sensor capture
