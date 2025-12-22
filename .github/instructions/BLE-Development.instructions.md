---
applyTo: 'lib/tools/**'
---

# BLE Development Guide

> Instructions for working with Bluetooth Low Energy device integration

## 🔗 BLE Architecture Overview

### Connection Flow (DO NOT BREAK)
```
User Action
  ↓
_SensorPickerSheet._connectAndAssign()
  ↓
bleService.connectToDevice(deviceId)
  ↓
reconnectService.markConnected(deviceId) ← MUST emit ReconnectStatus.connected
  ↓
DeviceDataService listens for connected event
  ↓
DeviceDataService._subscribeToDevice(deviceId)
  ↓
  - Discovers GATT services
  - Enables notifications on characteristic
  - Sends device-specific init commands
  ↓
Device starts streaming data
  ↓
DeviceDataService parses raw bytes
  ↓
StreamController emits typed measurements
  ↓
UI receives updates via StreamBuilder
```

**Critical:** The `markConnected()` method in `auto_reconnect_service.dart` MUST emit the `ReconnectStatus.connected` event. Without this, the subscription chain breaks and no data flows.

## 📁 Key Files

### Core Services
- **`device_registry.dart`** - Device profiles, UUIDs, parsing logic
- **`device_data_service.dart`** - Central data streaming hub
- **`auto_reconnect_service.dart`** - Background reconnection
- **`bluetooth_service.dart`** - Low-level BLE operations

### Device-Specific
- **`scale_settings.dart`** - Wey-Tek scale configuration
- **`ml_data_service.dart`** - Machine learning for protocol detection

### UI
- **`ble_sniffer_screen.dart`** - Protocol analyzer (admin only)
- **`device_scan_screen.dart`** - BLE scanner
- **`tek_devices_screen.dart`** - Device management

## 🔧 Adding a New BLE Device

### Step 1: Capture Protocol
Use the built-in BLE Sniffer:

1. **Open app** → Tools → Scan → Find device
2. **Tap "Scan"** → Select unknown device
3. **Open BLE Sniffer** (admin only) → Connect to device
4. **Auto-subscribe enabled** → Sniffer subscribes to ALL notify characteristics
5. **Interact with device** → Press buttons, change settings, take measurements
6. **Export logs** → Tap Export → Share console output
7. **Auto-sync to Firebase** → Logs saved to `ble_sniff_logs` collection

Alternative: Android HCI Snoop Log
```bash
# Enable on device: Settings → Developer Options → Bluetooth HCI snoop log
adb shell settings put global bluetooth_hci_log 1
adb shell setprop persist.bluetooth.btsnoopenable true

# Reproduce BLE interactions
# ...

# Pull logs
adb bugreport bugreport_$(date +%Y%m%d_%H%M%S).zip

# Analyze with Wireshark
# Extract: FS/data/misc/bluetooth/logs/btsnoop_hci.log
```

### Step 2: Analyze Protocol

Look for patterns in the captured data:

**Notification Data:**
- Measurement format (int8, int16, float, etc.)
- Byte order (little-endian, big-endian)
- Units (scaling factors, conversions)
- Flags (status bits, error codes)

**Initialization Sequence:**
- Required commands after connection
- Handshakes or authentication
- Configuration writes

**Example: Testo T115i Temperature**
```
Handshake:    56 00 03 00 00 00 0c 69 02 3e 81
Start stream: 20 01 00 00 00 00 3a bb
Data format:  11 03 [int16 temp*10] 00 00 00 [CRC16]
```

**Example: Wey-Tek Scale Weight**
```
Link:  aa aa aa aa 4c 00 00 00 00 00 00 4c 00
Ack:   aa aa aa aa 41 00 00 00 00 00 00 41 00
Init:  aa aa aa aa 49 00 00 00 00 00 00 49 00
Tare:  aa aa aa aa 4f 00 00 00 00 00 00 4f 00
Data:  aa aa aa aa 57 [flags] [int32 LE grams] [unit] [chk] 00
```

### Step 3: Add Device Profile

Edit `lib/tools/services/device_registry.dart`:

```dart
// Add service UUID constant
static const String YOUR_DEVICE_SERVICE = 'your-service-uuid';

// Add to serviceToProfile map
static final Map<String, DeviceProfile> serviceToProfile = {
  // ... existing devices ...
  
  YOUR_DEVICE_SERVICE: DeviceProfile(
    name: 'Your Device Name',
    manufacturer: 'Manufacturer Name',
    type: DeviceType.temperature, // or pressure, scale, airflow
    icon: Icons.device_thermostat,
    serviceUuid: YOUR_DEVICE_SERVICE,
    characteristicUuid: 'your-characteristic-uuid',
    requiresInit: true, // if init sequence needed
    parseCharacteristic: (uuid, data) {
      // Parse raw bytes to measurement
      if (data.length < 4) return null;
      
      // Example: int16 little-endian at offset 2
      final rawValue = data[2] | (data[3] << 8);
      final signedValue = rawValue > 32767 ? rawValue - 65536 : rawValue;
      final temperature = signedValue / 10.0; // scaling factor
      
      return TemperatureMeasurement(
        celsius: temperature,
        timestamp: DateTime.now(),
      );
    },
  ),
};

// Add to detectDeviceByName if needed
static DeviceProfile? detectDeviceByName(String name) {
  if (name.contains('YOUR DEVICE')) {
    return serviceToProfile[YOUR_DEVICE_SERVICE];
  }
  // ... existing detection logic ...
}
```

### Step 4: Add Data Parser

Edit `lib/tools/services/device_data_service.dart`:

```dart
Future<void> _subscribeToDevice(String deviceId) async {
  // ... existing code ...
  
  // Add your device's init sequence
  if (profile.requiresInit) {
    if (profile.serviceUuid == DeviceRegistry.YOUR_DEVICE_SERVICE) {
      await _initYourDevice(device, writeChar);
    }
  }
  
  // Subscription handles parsing via profile.parseCharacteristic
  notifyChar.onValueReceived.listen((data) {
    final measurement = profile.parseCharacteristic(
      profile.characteristicUuid,
      data,
    );
    if (measurement != null) {
      _dataController.add(measurement);
    }
  });
}

Future<void> _initYourDevice(
  BluetoothDevice device,
  BluetoothCharacteristic writeChar,
) async {
  // Send init commands
  await writeChar.write([0xAA, 0xBB, 0xCC], withoutResponse: false);
  await Future.delayed(Duration(milliseconds: 100));
  
  await writeChar.write([0x11, 0x22, 0x33], withoutResponse: false);
  await Future.delayed(Duration(milliseconds: 50));
  
  debugPrint('[BLE] Your Device initialized');
}
```

### Step 5: Test

1. **Connect device:** Tools → Scan → Select your device
2. **Verify connection:** Check device appears in Devices list
3. **Check data stream:** Open Tools Hub → Verify live readings
4. **Test edge cases:**
   - Device goes out of range → reconnects when back
   - App backgrounds → data resumes when reopened
   - Battery low → handles gracefully
   - Multiple devices → no conflicts

### Step 6: Document

Add protocol documentation:
```bash
# Create docs file
docs/BLE-Sniffing/YOUR_DEVICE_PROTOCOL.md
```

Include:
- Service and characteristic UUIDs
- Init sequence with byte values
- Data format with byte offsets
- Scaling factors and units
- Known issues or quirks
- Example packet captures

## 🚫 Common Mistakes

### 1. Not Checking `mounted` Before `setState()`
```dart
// ❌ BAD
Future<void> _connect() async {
  await bleService.connect();
  setState(() => _isConnected = true);
}

// ✅ GOOD
Future<void> _connect() async {
  await bleService.connect();
  if (mounted) {
    setState(() => _isConnected = true);
  }
}
```

### 2. Blocking UI with BLE Operations
```dart
// ❌ BAD - Blocks UI thread
void _readValue() {
  final value = characteristic.read().wait();
}

// ✅ GOOD - Async with loading state
Future<void> _readValue() async {
  setState(() => _isLoading = true);
  try {
    final value = await characteristic.read();
    _handleValue(value);
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

### 3. Not Disposing StreamSubscriptions
```dart
// ❌ BAD - Memory leak
StreamSubscription? _subscription;
@override
void initState() {
  _subscription = stream.listen((data) {});
}
// Missing dispose!

// ✅ GOOD
StreamSubscription? _subscription;
@override
void initState() {
  _subscription = stream.listen((data) {});
}
@override
void dispose() {
  _subscription?.cancel();
  super.dispose();
}
```

### 4. Hardcoding Device-Specific Logic
```dart
// ❌ BAD - Not scalable
if (deviceName == 'Testo T115i') {
  // Testo-specific code
} else if (deviceName == 'Wey-Tek Scale') {
  // Scale-specific code
}

// ✅ GOOD - Use device registry
final profile = DeviceRegistry.detectDeviceByName(deviceName);
if (profile != null) {
  final measurement = profile.parseCharacteristic(uuid, data);
}
```

### 5. Missing Error Handling
```dart
// ❌ BAD - Crashes on failure
await device.connect();

// ✅ GOOD - Graceful degradation
try {
  await device.connect(timeout: Duration(seconds: 10));
} on TimeoutException {
  _showError('Connection timed out');
} on Exception catch (e) {
  _showError('Failed to connect: $e');
}
```

## 🐛 Debugging BLE Issues

### Check Connection State
```dart
// Add logging to understand flow
debugPrint('[BLE] Connecting to ${device.name}...');
await device.connect();
debugPrint('[BLE] Connected, discovering services...');
await device.discoverServices();
debugPrint('[BLE] Services discovered');
```

### Verify Data Reception
```dart
notifyChar.onValueReceived.listen((data) {
  debugPrint('[BLE] Received ${data.length} bytes: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
  // ... process data ...
});
```

### Check Android Permissions
Required permissions in `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### Use Platform Tools
```bash
# Monitor BLE operations
adb logcat -s BluetoothGatt

# Check connected devices
adb shell dumpsys bluetooth_manager

# Enable verbose BLE logging
adb shell setprop log.tag.BluetoothGatt VERBOSE
```

## 📊 BLE Device Types

### Supported Measurement Types
```dart
enum DeviceType {
  temperature,  // Temp probes (Testo T115i)
  pressure,     // Pressure sensors (Testo T549i)
  scale,        // Refrigerant scales (Wey-Tek)
  airflow,      // Airflow meters (ABM-200)
  multimeter,   // Multi-meters (Fieldpiece)
  psychrometer, // Humidity/temp (Fieldpiece)
  unknown,      // Unidentified device
}
```

### Measurement Classes
```dart
class TemperatureMeasurement {
  final double celsius;
  final DateTime timestamp;
}

class PressureMeasurement {
  final double psi;
  final DateTime timestamp;
}

class WeightMeasurement {
  final double ounces;
  final String unit;
  final DateTime timestamp;
}

class AirflowMeasurement {
  final double cfm;
  final double? temperature;
  final double? humidity;
  final DateTime timestamp;
}
```

## 🔄 Auto-Reconnection

The app automatically reconnects to known devices:

1. **Device disconnects** → `AutoReconnectService` detects
2. **Scan starts** → Every 30 seconds
3. **Device found** → Auto-connect attempts
4. **Connection succeeds** → `markConnected()` emits event
5. **Data resumes** → DeviceDataService re-subscribes

**Important:** Don't interfere with this flow. The service manages reconnection lifecycle.

## 📖 Reference

### Fieldpiece Broadcast-Only Devices
Fieldpiece devices use **non-connectable advertisements**:
- Event type: `ADV_NONCONN_IND` (0x10)
- Manufacturer ID: `0x5046`
- Data in manufacturer-specific field
- **Cannot connect via GATT** - parse advertisements directly

```dart
// Scan for advertisements
flutterBluePlus.scanResults.listen((results) {
  for (var result in results) {
    final mfrData = result.advertisementData.manufacturerData;
    if (mfrData.containsKey(0x5046)) {
      final bytes = mfrData[0x5046]!;
      _parseFieldpieceData(bytes);
    }
  }
});
```

### Useful Resources
- [Bluetooth SIG Assigned Numbers](https://www.bluetooth.com/specifications/assigned-numbers/)
- [flutter_blue_plus Documentation](https://pub.dev/packages/flutter_blue_plus)
- [BLE GATT Services](https://www.bluetooth.com/specifications/gatt/services/)
- [Wireshark Bluetooth](https://wiki.wireshark.org/Bluetooth)
