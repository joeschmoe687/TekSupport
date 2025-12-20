# Fieldpiece BLE Protocol Analysis

## Discovery Summary (2024-12-19)

### Root Cause: Fieldpiece Devices Use Non-Connectable Advertisements

**The Fieldpiece devices broadcast measurement data directly in advertisement packets and DO NOT accept GATT connections.**

| Attribute | Value |
|-----------|-------|
| Manufacturer ID | `0x5046` (20550 decimal) = "PF" |
| MAC OUI | `D8:B6:73:*` (Texas Instruments) |
| BLE Event Type | `0x10` (ADV_NONCONN_IND) |
| Connectable | **NO** |
| Data Delivery | Manufacturer-specific advertisement data |

### Why TekTool Connection Fails

```
12-19 19:08:27.911 flutter: <connect> args: {remote_id: D8:B6:73:B3:FC:A0, auto_connect: 0}
12-19 19:08:37.956 BluetoothGatt: onClientConnectionState() - status=147 connected=false
12-19 19:08:37.957 [FBP-Android]: status: GATT_CONNECTION_TIMEOUT
```

**Status 147 = GATT_CONNECTION_TIMEOUT** because the device isn't listening for connection requests!

The Android Bluetooth stack reports `eventType=0x10` (non-connectable), but flutter_blue_plus still allows connection attempts.

### How Fieldpiece Job Link Works

The official Job Link app (`com.automateddecision.decom.fp`) reads data directly from advertisements:

```dart
// Example: Fieldpiece broadcasts measurement data in manufacturer_data
manufacturer_data: {20550: [66, 70, 34, 18, 137, 117, 18, 32, 34, 17, 40, 128, 2, 16, 243, 3, 4, 40, 6]}
```

### Advertisement Data Format

```
Manufacturer ID: 0x5046 (20550) = Fieldpiece
Data bytes: [66, 70, 34, 18, 137, 117, 18, 32, 34, 17, 40, 128, 2, 16, 243, 3, 4, 40, 6]
         Hex: 42 46 22 12 89 75 12 20 22 11 28 80 02 10 F3 03 04 28 06
```

| Bytes | Value | Meaning |
|-------|-------|---------|
| 0-1 | `42 46` | Device type "BF" |
| 2-5 | `22 12 89 75` | Device serial/ID (static) |
| 6 | `12`→`13` | State/battery indicator |
| 7-10 | `20 22 11 28` | Configuration |
| 11 | `80`→`84` | **Measurement value (changes with reading)** |
| 12-16 | `02 10 F3 03 04` | Additional data |
| 17 | `28`→`38` | **Measurement value (changes with reading)** |
| 18 | `06`→`15` | Packet counter |

### Solution for TekTool

**Don't try to connect to Fieldpiece devices.** Instead:

1. **Detect Fieldpiece** by manufacturer ID `0x5046` (20550)
2. **Read measurement data** directly from advertisement packets
3. **Parse manufacturer_data** bytes to extract readings
4. **Display values** without GATT connection

### Recommended Code Changes

```dart
// In ble_sniffer_screen.dart - detect non-connectable devices
bool isConnectable = result.advertisementData.connectable ?? true;

// Fieldpiece uses broadcast-only protocol
if (manufacturerId == 0x5046) {
  // Don't show "Connect" button - device is broadcast-only
  // Parse measurement data from manufacturer_data instead
  final data = manufacturerData[0x5046];
  if (data != null && data.length >= 18) {
    final measurement1 = data[11]; // Primary reading
    final measurement2 = data[17]; // Secondary reading
    // Display values directly from advertisement
  }
}
```

### Future Work

1. Reverse-engineer full Fieldpiece protocol (device types, units, scaling)
2. Add Fieldpiece decoder to BLE sniffer tool
3. Create Job Link integration/import feature
4. Document all Fieldpiece device model identifiers

### References

- [Bluetooth SIG Manufacturer IDs](https://www.bluetooth.com/specifications/assigned-numbers/)
- Fieldpiece Job Link app: `com.automateddecision.decom.fp`
- Texas Instruments BLE OUI: `D8:B6:73:*`, `84:C6:92:*`
