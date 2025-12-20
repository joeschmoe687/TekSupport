import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'device_registry.dart';
import 'auto_reconnect_service.dart';
import 'device_storage_service.dart';

/// Data reading from a connected device
class DeviceReading {
  final String deviceId;
  final String deviceName;
  final HvacDeviceType type;
  final double value;
  final String unit;
  final DateTime timestamp;
  final List<int>? rawData; // Raw BLE packet for multi-sensor devices (ABM-200)

  DeviceReading({
    required this.deviceId,
    required this.deviceName,
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.rawData,
  });

  @override
  String toString() => '$deviceName: $value $unit';
}

/// Battery reading from a connected device
class BatteryReading {
  final String deviceId;
  final String deviceName;
  final int level; // 0-100%
  final DateTime timestamp;

  BatteryReading({
    required this.deviceId,
    required this.deviceName,
    required this.level,
    required this.timestamp,
  });

  @override
  String toString() => '$deviceName: $level%';
}

/// Service for streaming data from connected BLE HVAC devices
class DeviceDataService {
  static final DeviceDataService _instance = DeviceDataService._internal();
  factory DeviceDataService() => _instance;
  DeviceDataService._internal();

  final DeviceRegistry _registry = DeviceRegistry();
  final AutoReconnectService _reconnectService = AutoReconnectService();
  final DeviceStorageService _storage = DeviceStorageService();

  // Active subscriptions per device (notifications)
  final Map<String, StreamSubscription> _dataSubscriptions = {};

  // Active polling timers per device (for devices without notifications)
  final Map<String, Timer> _pollingTimers = {};

  // Measurement polling timers (for Testo command polling)
  final Map<String, Timer> _measurementPollingTimers = {};

  // Write characteristics for sending commands
  final Map<String, ble.BluetoothCharacteristic> _writeCharacteristics = {};

  // Stream controller for readings
  final _readingsController = StreamController<DeviceReading>.broadcast();

  // Stream controller for battery level updates
  final _batteryController = StreamController<BatteryReading>.broadcast();

  // Latest readings per device
  final Map<String, DeviceReading> _latestReadings = {};

  // Latest battery levels per device (0-100%)
  final Map<String, int> _batteryLevels = {};

  bool _isInitialized = false;

  /// Stream of all device readings
  Stream<DeviceReading> get readings => _readingsController.stream;

  /// Stream of battery level updates
  Stream<BatteryReading> get batteryUpdates => _batteryController.stream;

  /// Get latest reading for a device
  DeviceReading? getLatestReading(String deviceId) => _latestReadings[deviceId];

  /// Get battery level for a device (0-100 or null if unknown)
  int? getBatteryLevel(String deviceId) => _batteryLevels[deviceId];

  /// Get all battery levels
  Map<String, int> get allBatteryLevels => Map.unmodifiable(_batteryLevels);

  /// Get all latest readings
  Map<String, DeviceReading> get allLatestReadings =>
      Map.unmodifiable(_latestReadings);

  /// Get readings by device type
  List<DeviceReading> getReadingsByType(HvacDeviceType type) {
    return _latestReadings.values.where((r) => r.type == type).toList();
  }

  /// Send a raw command to a device
  /// Returns true if command was sent successfully
  Future<bool> sendCommand(String deviceId, List<int> command) async {
    final writeChar = _writeCharacteristics[deviceId];
    if (writeChar == null) {
      print('[DeviceData] No write characteristic for $deviceId');
      return false;
    }

    try {
      final hex =
          command.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      print('[DeviceData] Sending command to $deviceId: $hex');
      // Use writeWithoutResponse if the characteristic supports it
      // (Wey-Tek scale only supports writeWithoutResponse, not write)
      await writeChar.write(command,
          withoutResponse: writeChar.properties.writeWithoutResponse);
      return true;
    } catch (e) {
      print('[DeviceData] Failed to send command to $deviceId: $e');
      return false;
    }
  }

  /// Send tare/zero command to Wey-Tek scale
  Future<bool> sendScaleTare(String deviceId) async {
    // Wey-Tek tare command: aa aa aa aa 4f 00 00 00 00 00 00 4f 00
    const tareCommand = [
      0xaa,
      0xaa,
      0xaa,
      0xaa,
      0x4f,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x4f,
      0x00
    ];
    return sendCommand(deviceId, tareCommand);
  }

  /// Initialize the data service
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _storage.init();
    await _reconnectService.init();

    // Listen for connection changes
    _reconnectService.reconnectStatus.listen((status) {
      if (status.state == ReconnectState.connected && status.deviceId != null) {
        _subscribeToDevice(status.deviceId!);
      } else if (status.state == ReconnectState.disconnected &&
          status.deviceId != null) {
        _unsubscribeFromDevice(status.deviceId!);
      }
    });

    // Subscribe to already connected devices
    for (final deviceId in _reconnectService.connectedDeviceIds) {
      await _subscribeToDevice(deviceId);
    }
  }

  /// Subscribe to data notifications for a connected device
  Future<void> _subscribeToDevice(String deviceId) async {
    // Don't subscribe twice
    if (_dataSubscriptions.containsKey(deviceId) ||
        _pollingTimers.containsKey(deviceId)) return;

    try {
      final device = ble.BluetoothDevice.fromId(deviceId);

      // Get saved device info to determine type
      final savedDevices = await _storage.getSavedDevices();
      final saved =
          savedDevices.where((d) => d.remoteId == deviceId).firstOrNull;

      // Get device name - try saved first, then fall back to platform name
      String deviceName;
      DeviceProfile? profileNullable;

      if (saved != null) {
        deviceName = saved.name;
        profileNullable = _registry.identifyByName(saved.name);
      } else {
        // Fallback: try to get the platform name from the device itself
        deviceName = device.platformName;
        print(
            '[DeviceData] No saved info for $deviceId, trying platform name: $deviceName');

        if (deviceName.isNotEmpty) {
          profileNullable = _registry.identifyByName(deviceName);
        }
      }

      if (profileNullable == null) {
        print('[DeviceData] Unknown device type for $deviceName');
        return;
      }

      // Non-null profile for use in closures
      final profile = profileNullable;

      // Discover services and find data characteristic
      final services = await device.discoverServices();

      // Log all services and characteristics for debugging
      print('[DeviceData] Services for $deviceName:');
      for (final service in services) {
        print('  Service: ${service.uuid}');
        for (final char in service.characteristics) {
          final props = <String>[];
          if (char.properties.read) props.add('read');
          if (char.properties.write) props.add('write');
          if (char.properties.notify) props.add('notify');
          if (char.properties.indicate) props.add('indicate');
          print('    Char: ${char.uuid} [${props.join(', ')}]');
        }
      }

      ble.BluetoothCharacteristic? dataChar;
      ble.BluetoothCharacteristic? writeChar;
      bool supportsNotify = false;

      // Wey-Tek HD Scale UUID (reverse-engineered Dec 18, 2025)
      const weytekServiceUuid = 'e3b744f3-4309-4a3a-b877-ccacd9efb97d';

      for (final service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();

        // === ABM-200 AIRFLOW METER ===
        // Service: 961f0001-d2d6-43e3-a417-3bb8217e0e01
        // Data Char: 961f0005 (notify, ~10Hz, 14 bytes)
        if (serviceUuid.contains('961f0001')) {
          print('[DeviceData] Found ABM-200 airflow meter service');
          for (final char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();
            if (charUuid.contains('961f0005') &&
                (char.properties.notify || char.properties.indicate)) {
              dataChar = char;
              supportsNotify = true;
              print('[DeviceData] Found ABM-200 data char: ${char.uuid}');
            }
          }
        }

        // === WEY-TEK HD SCALE ===
        // Service: E3B744F3-4309-4A3A-B877-CCACD9EFB97D
        // Single characteristic for read/write/notify (handle 0x0111)
        if (serviceUuid.contains(weytekServiceUuid)) {
          print('[DeviceData] Found Wey-Tek scale service');
          for (final char in service.characteristics) {
            if (char.properties.notify || char.properties.indicate) {
              dataChar = char;
              supportsNotify = true;
              print('[DeviceData] Found Wey-Tek notify char: ${char.uuid}');
            }
            if (char.properties.write || char.properties.writeWithoutResponse) {
              writeChar = char;
              print('[DeviceData] Found Wey-Tek write char: ${char.uuid}');
            }
          }
        }

        // === TESTO SMART PROBES ===
        // Check if this is the data service (fff0 for Testo)
        if (serviceUuid.contains('fff0')) {
          for (final char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();

            // fff2 is the notify/data characteristic for Testo
            if (charUuid.contains('fff2') &&
                (char.properties.notify || char.properties.indicate)) {
              dataChar = char;
              supportsNotify = true;
              print('[DeviceData] Found notify char fff2');
            }

            // fff1 is the write characteristic (for sending commands)
            if (charUuid.contains('fff1') && char.properties.write) {
              writeChar = char;
              print('[DeviceData] Found write char fff1');
            }
          }
        }
      }

      // Fallback: find any notifiable characteristic in fff0 service
      if (dataChar == null) {
        for (final service in services) {
          final serviceUuid = service.uuid.toString().toLowerCase();
          if (serviceUuid.contains('fff0')) {
            for (final char in service.characteristics) {
              if (char.properties.notify || char.properties.indicate) {
                dataChar = char;
                supportsNotify = true;
                print('[DeviceData] Using fallback notify char: ${char.uuid}');
                break;
              }
            }
          }
        }
      }

      if (dataChar == null) {
        print('[DeviceData] No data characteristic found for $deviceId');
        return;
      }

      print(
          '[DeviceData] Found char ${dataChar.uuid} on $deviceId (notify: $supportsNotify, read: ${dataChar.properties.read})');

      if (supportsNotify) {
        // Use notifications
        print('[DeviceData] Using notifications for $deviceId');
        await dataChar.setNotifyValue(true);

        final subscription = dataChar.onValueReceived.listen((data) {
          _handleData(deviceId, deviceName, profile, data);
        });

        _dataSubscriptions[deviceId] = subscription;

        // Send init commands based on device type
        if (writeChar != null) {
          _writeCharacteristics[deviceId] = writeChar;

          // Detect device type for appropriate init sequence
          final isWeytek = profile.manufacturer == HvacManufacturer.weytek;

          if (isWeytek) {
            // === WEY-TEK HD SCALE INIT ===
            // Protocol reverse-engineered Dec 18, 2025
            // Format: aa aa aa aa [cmd] 00 00 00 00 00 00 [chk] 00
            // Checksum: byte[11] = byte[4]
            print('[DeviceData] Sending Wey-Tek init sequence to $deviceId');

            final weytekInitCommands = [
              // 0x4C = "L" - Link/start streaming
              [
                0xaa,
                0xaa,
                0xaa,
                0xaa,
                0x4c,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x4c,
                0x00
              ],
              // 0x41 = "A" - Acknowledge/configure
              [
                0xaa,
                0xaa,
                0xaa,
                0xaa,
                0x41,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x41,
                0x00
              ],
              // 0x49 = "I" - Initialize
              [
                0xaa,
                0xaa,
                0xaa,
                0xaa,
                0x49,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x49,
                0x00
              ],
            ];

            for (final cmd in weytekInitCommands) {
              try {
                await writeChar.write(cmd,
                    withoutResponse: writeChar.properties.writeWithoutResponse);
                print(
                    '[DeviceData] Sent: ${cmd.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
                await Future.delayed(const Duration(milliseconds: 100));
              } catch (e) {
                print('[DeviceData] Wey-Tek init cmd failed: $e');
              }
            }
            print('[DeviceData] Wey-Tek init complete for $deviceId');
            // No polling needed - Wey-Tek streams continuously after init
          } else {
            // === TESTO SMART PROBE INIT ===
            try {
              // Testo Smart Probe protocol (reverse engineered from HCI snoop)
              // These are the EXACT bytes the Testo app sends
              print('[DeviceData] Sending Testo init sequence to $deviceId');

              // Exact Testo init commands with CRC (from btsnoop capture)
              final initCommands = [
                // Handshake/init
                [
                  0x56,
                  0x00,
                  0x03,
                  0x00,
                  0x00,
                  0x00,
                  0x0c,
                  0x69,
                  0x02,
                  0x3e,
                  0x81
                ],
                // Start streaming
                [0x20, 0x01, 0x00, 0x00, 0x00, 0x00, 0x3a, 0xbb],
                // Measurement request
                [0x11, 0x03, 0x00, 0x00, 0x00, 0x00, 0x47, 0x5a],
                // Additional measurement channel
                [0x11, 0x04, 0x00, 0x00, 0x00, 0x00, 0xf2, 0x9a],
              ];

              for (final cmd in initCommands) {
                try {
                  await writeChar.write(cmd,
                      withoutResponse:
                          writeChar.properties.writeWithoutResponse);
                  print(
                      '[DeviceData] Sent: ${cmd.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
                  await Future.delayed(const Duration(milliseconds: 100));
                } catch (e) {
                  // Skip failed commands
                }
              }

              print('[DeviceData] Init sequence sent to $deviceId');

              // Start periodic measurement request polling
              _startMeasurementPolling(deviceId, writeChar);
            } catch (e) {
              print('[DeviceData] Init command failed: $e');
            }
          }
        }
      } else if (dataChar.properties.read) {
        // Use polling (read every second)
        print('[DeviceData] Using polling for $deviceId');

        // Read immediately
        try {
          final data = await dataChar.read();
          _handleData(deviceId, deviceName, profile, data);
        } catch (e) {
          print('[DeviceData] Initial read failed: $e');
        }

        // Set up polling timer
        final timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          try {
            if (!device.isConnected) {
              timer.cancel();
              _pollingTimers.remove(deviceId);
              return;
            }
            final data = await dataChar!.read();
            _handleData(deviceId, deviceName, profile, data);
          } catch (e) {
            print('[DeviceData] Poll read error: $e');
          }
        });

        _pollingTimers[deviceId] = timer;
      } else {
        print('[DeviceData] Characteristic has no read or notify capability');
        return;
      }

      print('[DeviceData] Subscribed to $deviceId');
    } catch (e) {
      print('[DeviceData] Error subscribing to $deviceId: $e');
    }
  }

  /// Handle incoming data from a device
  void _handleData(
    String deviceId,
    String deviceName,
    DeviceProfile profile,
    List<int> rawData,
  ) {
    if (rawData.isEmpty) return;

    // Debug: log ALL raw data to see what's coming through
    final hex =
        rawData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    print('[DeviceData] RAW $deviceName (${rawData.length} bytes): $hex');

    // Check for battery level packet first (Testo probes)
    // Pattern: "BatteryLevel" = 42 61 74 74 65 72 79 4c 65 76 65 6c
    final batteryLevel = _parseBatteryLevel(rawData);
    if (batteryLevel != null) {
      _batteryLevels[deviceId] = batteryLevel;
      print('[DeviceData] Battery $deviceName: $batteryLevel%');
      _batteryController.add(BatteryReading(
        deviceId: deviceId,
        deviceName: deviceName,
        level: batteryLevel,
        timestamp: DateTime.now(),
      ));
      // Battery packets don't contain sensor readings, return early
      return;
    }

    // Parse the reading
    double value = double.nan;
    if (profile.parseReading != null) {
      value = profile.parseReading!(rawData);
    }

    // Skip packets that don't contain the data we need (parser returns NaN)
    if (value.isNaN) {
      return;
    }

    // Log successful parse
    print(
        '[DeviceData] $deviceName: ${value.toStringAsFixed(1)} ${profile.unit}');

    final reading = DeviceReading(
      deviceId: deviceId,
      deviceName: deviceName,
      type: profile.type,
      value: value,
      unit: profile.unit,
      timestamp: DateTime.now(),
      rawData: rawData,
    );

    _latestReadings[deviceId] = reading;
    _readingsController.add(reading);
  }

  // Command cycle counter for Testo polling
  final Map<String, int> _pollCycleCount = {};

  /// Start periodic measurement polling for Testo probes
  void _startMeasurementPolling(
      String deviceId, ble.BluetoothCharacteristic writeChar) {
    // Cancel any existing polling for this device
    _measurementPollingTimers[deviceId]?.cancel();
    _writeCharacteristics[deviceId] = writeChar;
    _pollCycleCount[deviceId] = 0;

    print('[DeviceData] Starting measurement polling for $deviceId');

    // Testo measurement request commands (with CRC from btsnoop capture)
    final pollCommands = [
      // Measurement request command
      [0x11, 0x03, 0x00, 0x00, 0x00, 0x00, 0x47, 0x5a],
      // Alternate channel measurement
      [0x11, 0x04, 0x00, 0x00, 0x00, 0x00, 0xf2, 0x9a],
    ];

    // Poll every 2 seconds to request fresh measurements
    _measurementPollingTimers[deviceId] = Timer.periodic(
      const Duration(milliseconds: 2000),
      (timer) async {
        try {
          final count = _pollCycleCount[deviceId] ?? 0;
          final cmd = pollCommands[count % pollCommands.length];

          await writeChar.write(cmd,
              withoutResponse: writeChar.properties.writeWithoutResponse);

          _pollCycleCount[deviceId] = count + 1;
        } catch (e) {
          print('[DeviceData] Measurement poll failed for $deviceId: $e');
          // Don't cancel on error - device might recover
        }
      },
    );
  }

  /// Unsubscribe from a device
  void _unsubscribeFromDevice(String deviceId) {
    _dataSubscriptions[deviceId]?.cancel();
    _dataSubscriptions.remove(deviceId);
    _pollingTimers[deviceId]?.cancel();
    _pollingTimers.remove(deviceId);
    _measurementPollingTimers[deviceId]?.cancel();
    _measurementPollingTimers.remove(deviceId);
    _writeCharacteristics.remove(deviceId);
    _latestReadings.remove(deviceId);
    _batteryLevels.remove(deviceId);
    print('[DeviceData] Unsubscribed from $deviceId');
  }

  /// Parse battery level from raw BLE data
  /// Testo probes send "BatteryLevel" packets with percentage value
  /// Pattern: "BatteryLevel" (42 61 74 74 65 72 79 4c 65 76 65 6c) + null + value
  /// Wey-Tek scale sends battery in Init response (0x49) at byte 6 (BCD encoded)
  int? _parseBatteryLevel(List<int> rawData) {
    // Wey-Tek scale: Init response (0x49) contains battery at byte 6
    // Format: aa aa aa aa 49 [flags] [battery_bcd] 00 02 00 00 [chk] 00
    // Battery is BCD encoded: 0x82 = 82% (8*10 + 2)
    if (rawData.length >= 13 &&
        rawData[0] == 0xaa &&
        rawData[1] == 0xaa &&
        rawData[2] == 0xaa &&
        rawData[3] == 0xaa &&
        rawData[4] == 0x49) {
      // Init response from Wey-Tek scale
      final batteryByte = rawData[6];
      // BCD decode: high nibble * 10 + low nibble
      final highNibble = (batteryByte >> 4) & 0x0F;
      final lowNibble = batteryByte & 0x0F;
      // Validate BCD (each nibble should be 0-9)
      if (highNibble <= 9 && lowNibble <= 9) {
        final battery = highNibble * 10 + lowNibble;
        if (battery >= 0 && battery <= 100) {
          print(
              '[DeviceData] Wey-Tek battery: $battery% (BCD 0x${batteryByte.toRadixString(16)})');
          return battery;
        }
      }
    }

    // "BatteryLevel" = [0x42, 0x61, 0x74, 0x74, 0x65, 0x72, 0x79, 0x4c, 0x65, 0x76, 0x65, 0x6c]
    const batteryPattern = [
      0x42, 0x61, 0x74, 0x74, 0x65, 0x72, 0x79, // "Battery"
      0x4c, 0x65, 0x76, 0x65, 0x6c // "Level"
    ];

    // Check if packet starts with "BatteryLevel"
    if (rawData.length >= batteryPattern.length + 2) {
      bool matches = true;
      for (int i = 0; i < batteryPattern.length; i++) {
        if (rawData[i] != batteryPattern[i]) {
          matches = false;
          break;
        }
      }

      if (matches) {
        // After "BatteryLevel" (12 bytes), expect null terminator then value
        // Format varies: could be single byte (0-100) or ASCII digits
        final valueStart = batteryPattern.length;

        // Skip null terminator if present
        int offset = valueStart;
        if (offset < rawData.length && rawData[offset] == 0x00) {
          offset++;
        }

        if (offset < rawData.length) {
          final firstByte = rawData[offset];

          // Check if it's a direct byte value (0-100)
          if (firstByte <= 100) {
            return firstByte;
          }

          // Check if it's ASCII digits (e.g., "85" for 85%)
          if (firstByte >= 0x30 && firstByte <= 0x39) {
            // ASCII '0'-'9'
            String digits = '';
            while (offset < rawData.length &&
                rawData[offset] >= 0x30 &&
                rawData[offset] <= 0x39) {
              digits += String.fromCharCode(rawData[offset]);
              offset++;
            }
            final parsed = int.tryParse(digits);
            if (parsed != null && parsed >= 0 && parsed <= 100) {
              return parsed;
            }
          }
        }
      }
    }

    // Also check for "evel" continuation packet (from split "BatteryLevel")
    // Pattern: "evel" = [0x65, 0x76, 0x65, 0x6c]
    const evelPattern = [0x65, 0x76, 0x65, 0x6c];
    if (rawData.length >= evelPattern.length + 2) {
      bool matches = true;
      for (int i = 0; i < evelPattern.length; i++) {
        if (rawData[i] != evelPattern[i]) {
          matches = false;
          break;
        }
      }

      if (matches) {
        // After "evel" (4 bytes), expect null then value
        int offset = evelPattern.length;
        if (offset < rawData.length && rawData[offset] == 0x00) {
          offset++;
        }

        if (offset < rawData.length) {
          final firstByte = rawData[offset];
          if (firstByte <= 100) {
            return firstByte;
          }
        }
      }
    }

    return null;
  }

  /// Manually trigger subscription for a device (call after connecting)
  Future<void> subscribeToDevice(String deviceId) async {
    await _subscribeToDevice(deviceId);
  }

  /// Dispose resources
  void dispose() {
    for (final sub in _dataSubscriptions.values) {
      sub.cancel();
    }
    _dataSubscriptions.clear();
    for (final timer in _pollingTimers.values) {
      timer.cancel();
    }
    _pollingTimers.clear();
    for (final timer in _measurementPollingTimers.values) {
      timer.cancel();
    }
    _measurementPollingTimers.clear();
    _writeCharacteristics.clear();
    _readingsController.close();
    _batteryController.close();
  }
}
