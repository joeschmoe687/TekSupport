# TekTool Development Workflow

## Quick Start Commands

### Prerequisites
```bash
# Verify Flutter is installed
which flutter
# Expected: /Users/joeykeilbarth/flutter/bin/flutter

# Check Flutter environment
flutter doctor

# Verify Android device connected
adb devices
# Expected: RFCY518ZA0Y (or your device ID)
```

### Running the App

#### Full Run Command (from any directory)
```bash
cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app && \
/Users/joeykeilbarth/flutter/bin/flutter run --device-id=RFCY518ZA0Y
```

#### From Project Directory
```bash
# Navigate to project
cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app

# Run with specific device
flutter run --device-id=RFCY518ZA0Y

# Run with verbose logging
flutter run --device-id=RFCY518ZA0Y --verbose

# Release mode
flutter run --device-id=RFCY518ZA0Y --release
```

### Hot Reload Workflow
```bash
# Start app
flutter run --device-id=RFCY518ZA0Y

# During development:
# Press 'r' - Hot reload (fast, preserves state)
# Press 'R' - Hot restart (full restart)
# Press 'q' - Quit
```

### Building APK

#### Debug APK
```bash
cd android && ./gradlew assembleDebug

# Install debug APK
adb install -r android/app/build/outputs/apk/debug/app-debug.apk

# Start app
adb shell am start -n com.tekneckjoe.tektool/.MainActivity

# Attach Flutter for hot reload
flutter attach -d RFCY518ZA0Y
```

#### Release APK
```bash
flutter build apk --release

# Output location:
# android/app/build/outputs/apk/release/app-release.apk
```

### Monitoring Logs

#### Flutter Logs (all app output)
```bash
# Automatically shown during 'flutter run'
# Or separately:
flutter logs --device-id=RFCY518ZA0Y
```

#### Android System Logs
```bash
# Filter for Flutter messages
adb logcat -s flutter

# Filter for BLE messages
adb logcat -s BluetoothGatt

# All app logs
adb logcat | grep "com.tekneckjoe.tektool"

# Continuous filtered log
adb logcat -s flutter -s BluetoothGatt
```

#### Testo Pressure Parsing Logs
```bash
# During 'flutter run', look for these tags:
flutter run --device-id=RFCY518ZA0Y | grep "\[Pressure\]"

# Or in separate terminal:
adb logcat | grep "\[Pressure\]"
```

**Expected log output when T549i connected:**
```
[Pressure] Full packet: 7469616c50726573737572659...
[Pressure] offset 18 Int16/10: 49284 -> 4928.4 mbar (71.48 psi)
[Pressure] Using Int16/10 at offset 18 (live capture confirmed)
```

### BLE Debugging

#### Enable HCI Snoop Logging
```bash
# Enable BLE packet capture
adb shell settings put global bluetooth_hci_log 1
adb shell setprop persist.bluetooth.btsnoopenable true

# Reboot Bluetooth stack
adb shell svc bluetooth disable && sleep 2 && adb shell svc bluetooth enable

# Or reboot device
adb reboot
```

#### Capture BLE Traffic
```bash
# Generate bugreport with HCI logs (takes ~30 seconds)
adb bugreport bugreport_$(date +%Y%m%d_%H%M%S).zip

# Extract btsnoop log
unzip -j bugreport_*.zip "FS/data/log/bt/btsnoop_hci.log" -d logs/hci/

# Analyze pressure packets
tail -c 500000 logs/hci/btsnoop_hci.log | xxd -c 24 -g 1 | grep -A 1 '74 69 61 6c 50 72 65 73 73 75 72 65'
```

**Testo Pressure Packet Structure:**
```
Hex: 74 69 61 6c 50 72 65 73 73 75 72 65 [timestamp 4B] 00 00 [Int16 LE value]
     t  i  a  l  P  r  e  s  s  u  r  e

Offsets (from packet start):
  0-11:  "tialPressure" (ASCII)
  12-15: Timestamp (4 bytes)
  16-17: 0x00 0x00 (padding)
  18-19: Int16 LE (pressure in mbar × 10)

Example: 84 c0 at offset 18-19
  → Int16 LE: 0xC084 = 49284
  → Divide by 10: 4928.4 mbar
  → Convert to psi: 4928.4 × 0.0145038 = 71.48 psi ✓
```

### Clean Rebuild
```bash
# Full clean
flutter clean && flutter pub get && flutter run --device-id=RFCY518ZA0Y

# Android-specific clean
cd android && ./gradlew clean && cd .. && flutter run --device-id=RFCY518ZA0Y

# Clear app data on device (fresh start)
adb shell pm clear com.tekneckjoe.tektool
```

### Testing

#### Unit Tests
```bash
# All tests
flutter test

# Specific test file
flutter test test/tools/services/device_registry_test.dart

# With coverage
flutter test --coverage
```

#### Widget Tests
```bash
flutter test test/screens/welcome_screen_test.dart
```

#### Integration Tests (requires device)
```bash
flutter test integration_test/app_test.dart --device-id=RFCY518ZA0Y
```

## Common Issues

### Flutter not found
```bash
# Add to ~/.zshrc or ~/.bashrc:
export PATH="$HOME/flutter/bin:$PATH"

# Reload shell
source ~/.zshrc
```

### Device not detected
```bash
# Check USB debugging enabled on Android device
# Check device authorization
adb devices

# If "unauthorized", accept prompt on device
# If not listed, try different USB cable/port
```

### Build errors after pulling changes
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run --device-id=RFCY518ZA0Y
```

### BLE not connecting
```bash
# Check Android location permission granted in app
# Check Bluetooth is enabled
# Check device is in range (RSSI > -80 dBm)

# Clear app data and reconnect
adb shell pm clear com.tekneckjoe.tektool
flutter run --device-id=RFCY518ZA0Y
```

### Hot reload not working
```bash
# Changes to native code, assets, or pubspec.yaml require hot restart (R)
# For major changes, full rebuild:
flutter run --device-id=RFCY518ZA0Y
```

## Development Checklist

Before committing code:
- [ ] `flutter analyze` passes with no errors
- [ ] `flutter test` passes
- [ ] Tested on physical Android device
- [ ] BLE devices connect and show correct data
- [ ] No debug code or commented-out code
- [ ] Logs don't contain sensitive information

## File Locations

- **BLE Services:** `lib/tools/services/`
- **Device Parsers:** `lib/tools/services/device_registry.dart`
- **Data Streaming:** `lib/tools/services/device_data_service.dart`
- **Screens:** `lib/screens/`, `lib/tools/screens/`
- **Tests:** `test/` (unit/widget), `integration_test/` (e2e)
- **Build Scripts:** `scripts/`
- **Logs:** `logs/hci/` (HCI snoop captures)

## Related Documentation

- [README.md](../README.md) - Project overview
- [TODO.md](../TODO.md) - Feature roadmap
- [test/README.md](../test/README.md) - Testing guide
- [BLE Development](.github/instructions/BLE-Development.instructions.md) - BLE-specific guidelines
