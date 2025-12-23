import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Device type categories
enum HvacDeviceType {
  refrigerantGauge,
  temperatureProbe,
  refrigerantScale,
  airflowMeter,
  pressureProbe,
  clampMeter,
  vacuumGauge,
  unknown,
}

/// Supported HVAC tool manufacturers
enum HvacManufacturer {
  weytek,
  ccs,
  testo,
  fieldpiece,
  parker,
  yellowJacket,
  weatherflow,
  unknown,
}

/// ABM-200 multi-sensor reading (velocity, temp, humidity, pressure)
class Abm200Reading {
  final int velocity; // FPM
  final double tempF; // Fahrenheit
  final double humidity; // %RH
  final double pressure; // in/WC or barometric

  const Abm200Reading({
    required this.velocity,
    required this.tempF,
    required this.humidity,
    required this.pressure,
  });

  @override
  String toString() =>
      'ABM-200: ${velocity}FPM, ${tempF.toStringAsFixed(1)}°F, ${humidity.toStringAsFixed(1)}%RH, ${pressure.toStringAsFixed(1)}P';
}

/// Device connection type
enum ConnectionType {
  gatt, // Standard GATT connection (most devices)
  broadcastOnly, // Broadcast-only devices (no GATT connection possible)
}

/// Device profile containing BLE UUIDs and parsing logic
class DeviceProfile {
  final String name;
  final HvacManufacturer manufacturer;
  final HvacDeviceType type;
  final List<String> serviceUuids;
  final String? dataCharacteristicUuid;
  final String? batteryCharacteristicUuid;
  final double Function(List<int> rawData)? parseReading;
  final String unit;
  final bool isBroadcastOnly;
  final ConnectionType connectionType;
  final int?
      manufacturerId; // For broadcast-only devices (e.g., Fieldpiece = 0x5046)

  const DeviceProfile({
    required this.name,
    required this.manufacturer,
    required this.type,
    required this.serviceUuids,
    this.dataCharacteristicUuid,
    this.batteryCharacteristicUuid,
    this.parseReading,
    required this.unit,
    this.isBroadcastOnly = false,
    this.connectionType = ConnectionType.gatt,
    this.manufacturerId,
  });
}

/// Registry of known HVAC Bluetooth devices
class DeviceRegistry {
  static final DeviceRegistry _instance = DeviceRegistry._internal();
  factory DeviceRegistry() => _instance;
  DeviceRegistry._internal();

  /// Known device profiles - refined with actual BLE sniffing
  final Map<String, DeviceProfile> _profiles = {
    // Weytek HD / Inficon Wey-Tek HD Refrigerant Scale
    // Protocol reverse-engineered Dec 18, 2025
    // Service UUID: E3B744F3-4309-4A3A-B877-CCACD9EFB97D
    // Data Characteristic: handle 0x0111 (read/write/notify)
    // CCCD: handle 0x0112 (enable notifications: write 01 00)
    // Data format: aa aa aa aa [cmd] [flags] [weight 4B LE] [?] [chk] [?]
    // Weight: int32_le(bytes[6:10]) / 1000.0 = ounces
    'weytek_scale': DeviceProfile(
      name: 'Weytek HD Scale',
      manufacturer: HvacManufacturer.weytek,
      type: HvacDeviceType.refrigerantScale,
      serviceUuids: ['e3b744f3-4309-4a3a-b877-ccacd9efb97d'],
      dataCharacteristicUuid:
          'e3b744f3-4309-4a3a-b877-ccacd9efb97d', // Handle 0x0111
      unit: 'oz',
      parseReading: _parseWeytekScale,
    ),

    // CCS Airflow Meter
    // TODO: Replace with actual UUIDs from BLE sniffing
    'ccs_airflow': DeviceProfile(
      name: 'CCS Airflow Meter',
      manufacturer: HvacManufacturer.ccs,
      type: HvacDeviceType.airflowMeter,
      serviceUuids: ['0000ffe0-0000-1000-8000-00805f9b34fb'], // Placeholder
      dataCharacteristicUuid: '0000ffe1-0000-1000-8000-00805f9b34fb',
      unit: 'CFM',
      parseReading: _parseCcsAirflow,
    ),

    // ABM-200 Airflow Meter (WeatherFlow / AAB / CPS)
    // BLE Protocol captured Dec 19, 2025 via TekTool sniffer
    // 14-byte packets at ~10Hz: velocity, temp, humidity, pressure
    'abm_200': DeviceProfile(
      name: 'ABM-200 Airflow Meter',
      manufacturer: HvacManufacturer.weatherflow,
      type: HvacDeviceType.airflowMeter,
      serviceUuids: ['961f0001-d2d6-43e3-a417-3bb8217e0e01'],
      dataCharacteristicUuid: '961f0005-d2d6-43e3-a417-3bb8217e0e01',
      batteryCharacteristicUuid:
          '00002a19-0000-1000-8000-00805f9b34fb', // Standard battery
      unit: 'FPM',
      parseReading: _parseAbm200,
    ),

    // Testo Smart Probes - Temperature (T115i)
    // fff0 service, fff1 = write (commands), fff2 = notify (data)
    'testo_temp_probe': DeviceProfile(
      name: 'Testo Smart Probe (Temp)',
      manufacturer: HvacManufacturer.testo,
      type: HvacDeviceType.temperatureProbe,
      serviceUuids: ['0000fff0-0000-1000-8000-00805f9b34fb'],
      dataCharacteristicUuid: '0000fff2-0000-1000-8000-00805f9b34fb',
      unit: '°F',
      parseReading: _parseTestoTemp,
    ),

    // Testo Smart Probes - Pressure (T549i, T550i)
    // fff0 service, fff1 = write (commands), fff2 = notify (data)
    'testo_pressure_probe': DeviceProfile(
      name: 'Testo Smart Probe (Pressure)',
      manufacturer: HvacManufacturer.testo,
      type: HvacDeviceType.pressureProbe,
      serviceUuids: ['0000fff0-0000-1000-8000-00805f9b34fb'],
      dataCharacteristicUuid: '0000fff2-0000-1000-8000-00805f9b34fb',
      unit: 'psig',
      parseReading: _parseTestoPressure,
    ),

    // Fieldpiece Devices - Broadcast-only (no GATT connection possible)
    // HCI Snoop captured Dec 21, 2025 - 4 devices tested via Job Link app
    // Manufacturer ID: 0x5046 (ASCII "FP" = Fieldpiece)
    // Data is encoded in manufacturer_data field of advertisements

    // Fieldpiece Temperature Clamp (FPBF) - Model 8975
    'fieldpiece_temp_clamp': DeviceProfile(
      name: 'Fieldpiece Temp Clamp',
      manufacturer: HvacManufacturer.fieldpiece,
      type: HvacDeviceType.temperatureProbe,
      serviceUuids: [], // No service UUIDs - broadcast only
      unit: '°F',
      isBroadcastOnly: true,
      manufacturerId: 0x5046,
      parseReading: parseFieldpieceTemp,
    ),

    // Fieldpiece Pressure Probe (FPBG) - Model 2975/2976
    'fieldpiece_pressure_probe': DeviceProfile(
      name: 'Fieldpiece Pressure Probe',
      manufacturer: HvacManufacturer.fieldpiece,
      type: HvacDeviceType.pressureProbe,
      serviceUuids: [],
      unit: 'psig',
      isBroadcastOnly: true,
      manufacturerId: 0x5046,
      parseReading: parseFieldpiecePressure,
    ),

    // Fieldpiece Psychrometer (FPBH) - Model 5699
    // Measures dry bulb, wet bulb, and relative humidity
    'fieldpiece_psychrometer': DeviceProfile(
      name: 'Fieldpiece Psychrometer',
      manufacturer: HvacManufacturer.fieldpiece,
      type: HvacDeviceType.temperatureProbe,
      serviceUuids: [],
      unit: '°F',
      isBroadcastOnly: true,
      manufacturerId: 0x5046,
      parseReading: parseFieldpiecePsychrometer,
    ),

    // Fieldpiece SC680 Meter (FPCB)
    'fieldpiece_sc680': DeviceProfile(
      name: 'Fieldpiece SC680 Meter',
      manufacturer: HvacManufacturer.fieldpiece,
      type: HvacDeviceType.clampMeter,
      serviceUuids: [],
      unit: 'A',
      isBroadcastOnly: true,
      manufacturerId: 0x5046,
      parseReading: parseFieldpieceSC680,
    ),
  };

  /// Get all known service UUIDs for scanning
  List<String> getAllServiceUuids() {
    final uuids = <String>{};
    for (final profile in _profiles.values) {
      uuids.addAll(profile.serviceUuids);
    }
    return uuids.toList();
  }

  /// Try to identify a device by its advertised service UUIDs or manufacturer data
  DeviceProfile? identifyDevice(dynamic scanResultOrUuids) {
    List<String> advertisedServiceUuids;
    Map<int, List<int>>? manufacturerData;
    String? deviceName;

    // Handle flutter_blue_plus ScanResult or plain List<String>
    if (scanResultOrUuids is List<String>) {
      advertisedServiceUuids = scanResultOrUuids;
    } else {
      // Assume it's a ScanResult-like object
      try {
        final serviceUuids = scanResultOrUuids.advertisementData?.serviceUuids;
        advertisedServiceUuids =
            (serviceUuids as List?)?.map((e) => e.toString()).toList() ?? [];
        deviceName = scanResultOrUuids.device?.platformName as String?;
        manufacturerData = scanResultOrUuids.advertisementData?.manufacturerData
            as Map<int, List<int>>?;
        // Try to extract manufacturer data from scan result
        if (manufacturerData == null) {
          try {
            manufacturerData = scanResultOrUuids
                .advertisementData?.manufacturerData as Map<int, List<int>>?;
          } catch (_) {}
        }
      } catch (_) {
        advertisedServiceUuids = [];
      }
    }

    // First check manufacturer data for broadcast-only devices (like Fieldpiece)
    if (manufacturerData != null && manufacturerData.isNotEmpty) {
      for (final profile in _profiles.values) {
        if (profile.manufacturerId != null &&
            manufacturerData.containsKey(profile.manufacturerId)) {
          // Found a match by manufacturer ID - now identify specific device type
          return _identifyFieldpieceDeviceType(
              manufacturerData[profile.manufacturerId]!);
        }
      }
    }

    // Then try to match by service UUID
    for (final profile in _profiles.values) {
      for (final uuid in profile.serviceUuids) {
        if (advertisedServiceUuids
            .any((adv) => adv.toLowerCase() == uuid.toLowerCase())) {
          return profile;
        }
      }
    }

    // Fallback to name matching if device name is available
    if (deviceName != null && deviceName.isNotEmpty) {
      return identifyByName(deviceName);
    }

    return null;
  }

  /// Try to identify a device by name pattern
  DeviceProfile? identifyByName(String deviceName) {
    final nameLower = deviceName.toLowerCase();

    // Fieldpiece devices - usually advertise as "SC..." or "JL3..."
    // But since they're broadcast-only, should be identified by manufacturer ID instead
    if (nameLower.contains('fieldpiece') ||
        nameLower.startsWith('sc') ||
        nameLower.startsWith('jl')) {
      // Return a generic Fieldpiece profile - actual type determined by manufacturer data
      return _profiles['fieldpiece_temp'];
    }

    // ABM-200 Airflow Meter - advertises as "ABM-200 XXX"
    // TS-100 Airflow Meter - advertises as "TS-100 XXX" (AAB/CPS model)
    if (nameLower.contains('abm-200') || 
        nameLower.contains('abm200') ||
        nameLower.contains('ts-100') ||
        nameLower.contains('ts100')) {
      return _profiles['abm_200'];
    }

    // Wey-Tek HD Scale - advertises as "Scale" or contains "weytek/wey"
    if (nameLower == 'scale' ||
        nameLower.contains('weytek') ||
        nameLower.contains('wey-tek') ||
        nameLower.contains('wey')) {
      return _profiles['weytek_scale'];
    }
    if (nameLower.contains('ccs')) {
      return _profiles['ccs_airflow'];
    }

    // Testo Smart Probes - match by model number or brand
    // T115i = temperature probe
    // T549i, T550i = pressure/vacuum probes
    if (nameLower.contains('testo') ||
        nameLower.contains('t115') ||
        nameLower.contains('t549') ||
        nameLower.contains('t550')) {
      // Temperature probes: T115i
      if (nameLower.contains('t115')) {
        return _profiles['testo_temp_probe'];
      }
      // Pressure probes: T549i, T550i
      if (nameLower.contains('t549') || nameLower.contains('t550')) {
        return _profiles['testo_pressure_probe'];
      }
      // Fallback checks for testo brand name
      if (nameLower.contains('temp') || nameLower.contains('115')) {
        return _profiles['testo_temp_probe'];
      }
      if (nameLower.contains('pres') ||
          nameLower.contains('549') ||
          nameLower.contains('550')) {
        return _profiles['testo_pressure_probe'];
      }
      // Default to temp probe for unknown testo devices
      return _profiles['testo_temp_probe'];
    }

    return null;
  }

  /// Get profile by key
  DeviceProfile? getProfile(String key) => _profiles[key];

  /// Get profile by service UUID (for backward compatibility with tests)
  DeviceProfile? getProfileByServiceUuid(String serviceUuid) {
    for (final profile in _profiles.values) {
      if (profile.serviceUuids
          .any((uuid) => uuid.toLowerCase() == serviceUuid.toLowerCase())) {
        return profile;
      }
    }
    return null;
  }

  /// Get profile by device name (for backward compatibility with tests)
  DeviceProfile? getProfileByName(String deviceName) {
    return identifyByName(deviceName);
  }

  /// Get all profiles
  List<DeviceProfile> getAllProfiles() => _profiles.values.toList();

  /// Add a custom profile (for expandability)
  void addCustomProfile(String key, DeviceProfile profile) {
    _profiles[key] = profile;
  }

  /// Identify specific Fieldpiece device type from manufacturer data
  /// Fieldpiece packet format (from HCI snoop Dec 21, 2025):
  /// Bytes 0-1: "FP" manufacturer ID (already verified by caller)
  /// Bytes 2-3: Device type code - "BF"=Temp, "BG"=Pressure, "BH"=Psychrometer, "CB"=SC680
  DeviceProfile? _identifyFieldpieceDeviceType(List<int> manufacturerData) {
    if (manufacturerData.length < 4) return null;

    // Skip manufacturer ID bytes 0-1 ("FP")
    // Bytes 2-3 contain device type code
    final deviceTypeCode = String.fromCharCodes(manufacturerData.sublist(2, 4));

    switch (deviceTypeCode) {
      case 'BF':
        return _profiles['fieldpiece_temp_clamp'];
      case 'BG':
        return _profiles['fieldpiece_pressure_probe'];
      case 'BH':
        return _profiles['fieldpiece_psychrometer'];
      case 'CB':
        return _profiles['fieldpiece_sc680'];
      default:
        // Unknown Fieldpiece device - return generic temp probe
        return _profiles['fieldpiece_temp_clamp'];
    }
  }
}

// ============================================================================
// PARSING FUNCTIONS
// Actual data formats from BLE sniffing (Dec 2025)
// ============================================================================

/// Parse Weytek HD scale reading from raw BLE data
/// Protocol reverse-engineered Dec 18, 2025
/// Data format: aa aa aa aa [cmd] [flags] [weight 4B LE] [unit?] [chk] [?]
/// Byte 4: Command (0x57 = weight data, 0x5A = tare response)
/// Byte 5: Flags (0x02 = stable, 0x03 = unstable/settling)
/// Bytes 6-9: Weight as int32 little-endian in GRAMS
/// Byte 10: Unit indicator (0x00=lb, 0x01=lb:oz, 0x02=kg, 0x03=oz)
double _parseWeytekScale(List<int> rawData) {
  // Minimum packet length: 13 bytes
  if (rawData.length < 13) return double.nan;

  // Verify header: aa aa aa aa
  if (rawData[0] != 0xaa ||
      rawData[1] != 0xaa ||
      rawData[2] != 0xaa ||
      rawData[3] != 0xaa) {
    return double.nan;
  }

  // Check command byte - 0x57 = weight data, 0x5A = tare response
  if (rawData[4] != 0x57 && rawData[4] != 0x5A) {
    // Not a weight packet (could be 0x4C link, 0x41 ack, 0x49 init response)
    return double.nan;
  }

  // Extract weight (bytes 6-9, signed 32-bit little-endian)
  final bytes = Uint8List.fromList(rawData.sublist(6, 10));
  final byteData = ByteData.view(bytes.buffer);
  final rawWeight = byteData.getInt32(0, Endian.little);

  // Raw weight is in GRAMS - convert to ounces
  // 1 gram = 0.035274 ounces (1 oz = 28.3495 g)
  final ounces = rawWeight / 28.3495;

  // Check stability flag (byte 5)
  // 0x02 = stable, 0x03 = unstable/settling
  // final isStable = rawData[5] == 0x02;

  // Return ounces - can convert to lbs in UI if needed (oz / 16.0)
  return ounces;
}

/// Parse CCS airflow meter reading from raw BLE data
/// Placeholder - update after sniffing actual device
double _parseCcsAirflow(List<int> rawData) {
  if (rawData.length < 2) return 0.0;

  final bytes = Uint8List.fromList(rawData);
  final byteData = ByteData.view(bytes.buffer);

  try {
    // Airflow is typically whole CFM values
    final rawValue = byteData.getInt16(0, Endian.little);
    return rawValue.toDouble();
  } catch (e) {
    return 0.0;
  }
}

/// Parse ABM-200 airflow meter reading from raw BLE data
/// 14-byte packets streaming at ~10Hz
/// Byte offsets reverse-engineered Dec 19, 2025:
/// [0-1] Velocity  [4-5] Temp  [8-9] Humidity  [12-13] Pressure
Abm200Reading _parseAbm200Full(List<int> rawData) {
  if (rawData.length < 14) {
    return Abm200Reading(
        velocity: 0,
        tempF: double.nan,
        humidity: double.nan,
        pressure: double.nan);
  }

  final bytes = Uint8List.fromList(rawData);
  final byteData = ByteData.view(bytes.buffer);

  // Bytes 0-1: Airflow velocity (uint16 LE, FPM)
  final velocity = byteData.getUint16(0, Endian.little);

  // Bytes 4-5: Temperature (uint16 LE - 132) ÷10 = °F
  // Offset calibrated against CPS Link app Dec 19, 2025
  final tempRaw = byteData.getUint16(4, Endian.little);
  final tempF = (tempRaw - 132) / 10.0;

  // Bytes 8-9: Humidity (uint16 LE ÷5.29 = %RH)
  // Divisor calibrated against CPS Link app Dec 19, 2025
  final humidityRaw = byteData.getUint16(8, Endian.little);
  final humidity = humidityRaw / 5.29;

  // Bytes 12-13: Barometric Pressure (uint16 LE × 0.0401463 = in/WC)
  // Raw value is Pa/10, convert: Pa × 0.00401463 = in/WC
  final pressureRaw = byteData.getUint16(12, Endian.little);
  final pressure = pressureRaw * 0.0401463;

  return Abm200Reading(
    velocity: velocity,
    tempF: tempF,
    humidity: humidity,
    pressure: pressure,
  );
}

/// Simple parser for DeviceProfile - returns velocity only
/// Use _parseAbm200Full() for complete readings
double _parseAbm200(List<int> rawData) {
  if (rawData.length < 2) return 0.0;

  final bytes = Uint8List.fromList(rawData);
  final byteData = ByteData.view(bytes.buffer);

  // Bytes 0-1: Airflow velocity (uint16 LE, FPM)
  return byteData.getUint16(0, Endian.little).toDouble();
}

/// Parse Testo temperature probe reading from raw BLE data
/// Only parses ASCII packets containing "erature" pattern + Float32
/// 8-byte status packets (08 00 00 00 00 00 01 53) are ignored
double _parseTestoTemp(List<int> rawData) {
  // Skip 8-byte status packets - they don't contain real measurements
  // Status format: 08 00 00 00 00 00 01 53
  if (rawData.length <= 8) return double.nan;

  // Look for "erature" pattern (end of "LineTemperature" or "Temperature")
  const eraturePattern = [0x65, 0x72, 0x61, 0x74, 0x75, 0x72, 0x65];

  // Check if this packet starts with "erature" (15-byte continuation packet)
  // Format: "erature" + Float32(4 bytes) + extras
  // Example: 65 72 61 74 75 72 65 92 2b a0 41 01 00 3c bc
  if (rawData.length >= 11 && _matchesPattern(rawData, 0, eraturePattern)) {
    final bytes = Uint8List.fromList(rawData.sublist(7, 11));
    final byteData = ByteData.view(bytes.buffer);
    final celsius = byteData.getFloat32(0, Endian.little);
    if (celsius.isFinite && celsius > -50 && celsius < 200) {
      final fahrenheit = celsius * 9.0 / 5.0 + 32.0;
      return fahrenheit;
    }
  }

  // Check for "erature" anywhere in longer packets
  for (int i = 0; i <= rawData.length - 11; i++) {
    if (_matchesPattern(rawData, i, eraturePattern)) {
      if (i + 10 < rawData.length) {
        final bytes = Uint8List.fromList(rawData.sublist(i + 7, i + 11));
        final byteData = ByteData.view(bytes.buffer);
        final celsius = byteData.getFloat32(0, Endian.little);
        if (celsius.isFinite && celsius > -50 && celsius < 200) {
          final fahrenheit = celsius * 9.0 / 5.0 + 32.0;
          return fahrenheit;
        }
      }
    }
  }

  return double.nan;
}

/// Parse Testo pressure probe reading from raw BLE data
/// Only parses ASCII packets containing "ressure" pattern + Float32
/// 8-byte status packets are ignored
/// Note: Testo reports differential pressure in mbar, converted to psig
double _parseTestoPressure(List<int> rawData) {
  // Skip 8-byte status packets - they don't contain real measurements
  if (rawData.length <= 8) return double.nan;

  // Look for "ressure" pattern (end of "DifferentialPressure" or "Pressure")
  const ressurePattern = [0x72, 0x65, 0x73, 0x73, 0x75, 0x72, 0x65];

  // Check if packet starts with "tialPressure" (continuation of DifferentialPressure)
  // Format: 74 69 61 6c 50 72 65 73 73 75 72 65 [Float32 4 bytes] ...
  //         t  i  a  l  P  r  e  s  s  u  r  e  [value at byte 12-15]
  const tialPressurePattern = [
    0x74,
    0x69,
    0x61,
    0x6c,
    0x50,
    0x72,
    0x65,
    0x73,
    0x73,
    0x75,
    0x72,
    0x65
  ]; // "tialPressure"

  if (rawData.length >= 16 &&
      _matchesPattern(rawData, 0, tialPressurePattern)) {
    // Debug: dump full packet for analysis
    debugPrint('[Pressure] Full packet: ${bytesToHex(rawData)}');

    // Float32 starts after "tialPressure" + null terminator (byte 13)
    // Try multiple interpretations to find valid pressure
    double? validMbar;

    // Try 1: Int16 at bytes 13-14 with /100 scaling (most likely format based on data analysis)
    // This appears to be how Testo encodes differential pressure
    if (rawData.length >= 15 && rawData[12] == 0x00) {
      final bytes = Uint8List.fromList(rawData.sublist(13, 15));
      final byteData = ByteData.view(bytes.buffer);
      final rawInt16 = byteData.getInt16(0, Endian.little);
      final mbarFromInt = rawInt16 / 100.0;
      debugPrint(
          '[Pressure] bytes 13-14 Int16/100: $rawInt16 -> $mbarFromInt mbar (${(mbarFromInt * 0.0145038).toStringAsFixed(2)} psi)');

      // Valid range: -1100 to 50000 mbar (about -16 to 725 psi)
      if (mbarFromInt > -1100 && mbarFromInt < 50000) {
        validMbar = mbarFromInt;
        debugPrint('[Pressure] Using Int16/100 interpretation');
      }
    }

    // Try 2: bytes 13-16 as Float32 little-endian (fallback)
    if (validMbar == null && rawData.length >= 17 && rawData[12] == 0x00) {
      final bytes = Uint8List.fromList(rawData.sublist(13, 17));
      final byteData = ByteData.view(bytes.buffer);

      // Try little-endian
      final mbarLE = byteData.getFloat32(0, Endian.little);
      debugPrint(
          '[Pressure] bytes 13-16 LE: ${bytesToHex(rawData.sublist(13, 17))}, mbar: $mbarLE');

      // Try big-endian
      final mbarBE = byteData.getFloat32(0, Endian.big);
      debugPrint('[Pressure] bytes 13-16 BE: mbar: $mbarBE');

      // Use whichever is in valid range (-1100 to 50000 mbar)
      if (mbarLE.isFinite && mbarLE > -1100 && mbarLE < 50000) {
        validMbar = mbarLE;
      } else if (mbarBE.isFinite && mbarBE > -1100 && mbarBE < 50000) {
        validMbar = mbarBE;
        debugPrint('[Pressure] Using big-endian interpretation');
      }
    }

    // Try 3: bytes 14-17 (skip null + possible padding byte) - Float32
    if (validMbar == null && rawData.length >= 18) {
      final bytes = Uint8List.fromList(rawData.sublist(14, 18));
      final byteData = ByteData.view(bytes.buffer);

      final mbarLE = byteData.getFloat32(0, Endian.little);
      final mbarBE = byteData.getFloat32(0, Endian.big);

      if (mbarLE.isFinite && mbarLE > -1100 && mbarLE < 50000) {
        validMbar = mbarLE;
        debugPrint('[Pressure] Using bytes 14-17 LE Float32: $mbarLE mbar');
      } else if (mbarBE.isFinite && mbarBE > -1100 && mbarBE < 50000) {
        validMbar = mbarBE;
        debugPrint('[Pressure] Using bytes 14-17 BE Float32: $mbarBE mbar');
      }
    }

    // Try 4: bytes 12-15 as Float32 (no null terminator) - observed in captures
    if (validMbar == null && rawData.length >= 16) {
      final bytes = Uint8List.fromList(rawData.sublist(12, 16));
      final byteData = ByteData.view(bytes.buffer);
      final mbarLE = byteData.getFloat32(0, Endian.little);
      final mbarBE = byteData.getFloat32(0, Endian.big);
      if (mbarLE.isFinite && mbarLE > -1100 && mbarLE < 50000) {
        validMbar = mbarLE;
        debugPrint('[Pressure] Using bytes 12-15 LE Float32: $mbarLE mbar');
      } else if (mbarBE.isFinite && mbarBE > -1100 && mbarBE < 50000) {
        validMbar = mbarBE;
        debugPrint('[Pressure] Using bytes 12-15 BE Float32: $mbarBE mbar');
      }
    }

    // Try 5: heuristic scan for Int16 values near label (÷10 or ÷100)
    if (validMbar == null) {
      // Search window after the "tialPressure" text
      final start = 12; // first byte after the label
      final end = rawData.length - 1;
      for (int off = start; off + 1 < end; off++) {
        final b0 = rawData[off];
        final b1 = rawData[off + 1];
        final bytes = Uint8List.fromList([b0, b1]);
        final bd = ByteData.view(bytes.buffer);
        final s16 = bd.getInt16(0, Endian.little);

        // Try divisors commonly seen in Testo packets
        final candidatesMbar = <double>{
          s16 / 10.0,
          s16 / 100.0,
        };
        for (final mbar in candidatesMbar) {
          if (mbar.isFinite && mbar > -1100 && mbar < 50000) {
            validMbar = mbar;
            debugPrint('[Pressure] Using Int16 heuristic at +$off: $s16 -> $mbar mbar');
            break;
          }
        }
        if (validMbar != null) break;
      }
    }

    if (validMbar != null) {
      // Convert mbar to psi (1 mbar = 0.0145038 psi)
      final psi = validMbar * 0.0145038;
      debugPrint(
          '[Pressure] Result: $validMbar mbar = ${psi.toStringAsFixed(2)} psi');
      return psi;
    } else {
      // Log all attempted values for debugging
      debugPrint('[Pressure] No valid pressure found in packet');
    }
  } else if (rawData.length >= 16) {
    // Debug: log first 12 bytes to see what pattern we're getting
    debugPrint(
        '[Pressure] Pattern mismatch. First 12 bytes: ${bytesToHex(rawData.sublist(0, 12 > rawData.length ? rawData.length : 12))}');
  }

  // Generic search for "ressure" pattern in any packet
  for (int i = 0; i <= rawData.length - 11; i++) {
    if (_matchesPattern(rawData, i, ressurePattern)) {
      // After "ressure" (7 bytes), data follows. Try Float32 and Int16 heuristics.
      final valueStart = i + 7;
      // Float32 attempt
      if (valueStart + 4 <= rawData.length) {
        final bytes =
            Uint8List.fromList(rawData.sublist(valueStart, valueStart + 4));
        final byteData = ByteData.view(bytes.buffer);
        final mbarLE = byteData.getFloat32(0, Endian.little);
        final mbarBE = byteData.getFloat32(0, Endian.big);
        if (mbarLE.isFinite && mbarLE > -1100 && mbarLE < 50000) {
          return mbarLE * 0.0145038;
        }
        if (mbarBE.isFinite && mbarBE > -1100 && mbarBE < 50000) {
          return mbarBE * 0.0145038;
        }
      }

      // Int16 ÷10/÷100 attempt within next few bytes
      for (int off = valueStart; off + 1 < rawData.length && off < valueStart + 6; off++) {
        final bytes = Uint8List.fromList([rawData[off], rawData[off + 1]]);
        final bd = ByteData.view(bytes.buffer);
        final s16 = bd.getInt16(0, Endian.little);
        final mbar10 = s16 / 10.0;
        final mbar100 = s16 / 100.0;
        if (mbar10.isFinite && mbar10 > -1100 && mbar10 < 50000) {
          return mbar10 * 0.0145038;
        }
        if (mbar100.isFinite && mbar100 > -1100 && mbar100 < 50000) {
          return mbar100 * 0.0145038;
        }
      }
    }
  }

  return double.nan;
}

/// Parse Fieldpiece Temperature Clamp (FPBF Model 8975)
/// HCI snoop captured Dec 21, 2025:
/// Packet size: 22 bytes (0x16)
/// Bytes 0-1: "FP" manufacturer ID
/// Bytes 2-3: "BF" device type
/// Bytes 6-7: Model number (0x8975)
/// Byte 9: Battery level (0x20 = good, needs more data to decode scale)
/// Bytes 12-13: Temperature (uint16 LE, needs divisor confirmation)
/// Example: 0xa828 = 43048 → possible °C*1000 or °F*100
double parseFieldpieceTemp(List<int> rawData) {
  if (rawData.length < 14) return double.nan;

  final bytes = Uint8List.fromList(rawData);
  final byteData = ByteData.view(bytes.buffer);

  try {
    // Temperature at bytes 12-13 (from HCI analysis)
    // Sample: 0xa828 = 43048
    // If this is 68°F (liquid temp from screenshot), then:
    //   68°F = 20°C → 43048 / 2150 ≈ 20°C (possible)
    //   OR 43048 / 100 = 430.48 (unlikely)
    //   OR 43048 / 1000 = 43.048°C = 109°F (from analysis)
    // Try multiple interpretations
    final tempRaw = byteData.getUint16(12, Endian.little);
    
    // Try interpretation 1: raw value / 1000 = °C
    double tempC = tempRaw / 1000.0;
    double tempF = tempC * 9.0 / 5.0 + 32.0;
    if (tempF >= 0 && tempF <= 200) {
      return tempF;
    }
    
    // Try interpretation 2: raw value / 10 = °F
    tempF = tempRaw / 10.0;
    if (tempF >= 0 && tempF <= 200) {
      return tempF;
    }
    
    // Try interpretation 3: raw value / 100 = °F
    tempF = tempRaw / 100.0;
    if (tempF >= 0 && tempF <= 200) {
      return tempF;
    }
  } catch (_) {}

  return double.nan;
}

/// Parse Fieldpiece Pressure Probe (FPBG Model 2975/2976)
/// HCI snoop captured Dec 21, 2025:
/// Packet size: 28 bytes (0x1C)
/// Bytes 0-1: "FP" manufacturer ID
/// Bytes 2-3: "BG" device type
/// Bytes 6-7: Model number (0x2975 or 0x2976)
/// Byte 9: Battery level (0x20 = good)
/// Bytes 12-13: Pressure data
/// Example: 0x2877 = 10359 when pressure is 0.0 psig (zero offset)
/// Note: Need readings with actual pressure to determine offset and scale
double parseFieldpiecePressure(List<int> rawData) {
  if (rawData.length < 14) return double.nan;

  final bytes = Uint8List.fromList(rawData);
  final byteData = ByteData.view(bytes.buffer);

  try {
    // Pressure at bytes 12-13
    // From HCI: 0x2877 = 10359 when displaying 0.0 psig
    // This suggests an offset-based encoding
    final pressureRaw = byteData.getUint16(12, Endian.little);
    
    // Hypothesis 1: Zero offset at ~10359, scale unknown
    // If offset is 10359, then (raw - 10359) / 10 = psig?
    const zeroOffset = 10359;
    double psig = (pressureRaw - zeroOffset) / 10.0;
    if (psig >= -30 && psig <= 800) {
      return psig;
    }
    
    // Hypothesis 2: Direct scaled value
    psig = pressureRaw / 100.0;
    if (psig >= -30 && psig <= 800) {
      return psig;
    }
    
    // Hypothesis 3: Signed value with offset
    final pressureSigned = byteData.getInt16(12, Endian.little);
    psig = pressureSigned / 10.0;
    if (psig >= -30 && psig <= 800) {
      return psig;
    }
  } catch (_) {}

  return double.nan;
}

/// Parse Fieldpiece Psychrometer (FPBH Model 5699)
/// HCI snoop captured Dec 21, 2025:
/// Packet size: 30 bytes
/// Bytes 15-16: Wet bulb temp = uint16 LE ÷ 10 = °F (CONFIRMED)
/// Example: 0x022d = 557 ÷ 10 = 55.7°F ✓ matches screenshot
/// Bytes 12-13: Dry bulb temp (needs more data to confirm formula)
/// Bytes 20-21: Humidity % (needs more data to confirm formula)
double parseFieldpiecePsychrometer(List<int> rawData) {
  if (rawData.length < 17) return double.nan;

  final bytes = Uint8List.fromList(rawData);
  final byteData = ByteData.view(bytes.buffer);

  try {
    // Wet bulb temperature at bytes 15-16 (CONFIRMED via HCI snoop)
    final wetBulbRaw = byteData.getUint16(15, Endian.little);
    final wetBulbF = wetBulbRaw / 10.0;

    // Sanity check: valid wet bulb temps are 0-120°F
    if (wetBulbF >= 0 && wetBulbF <= 120) {
      return wetBulbF;
    }
  } catch (_) {}

  return double.nan;
}

/// Get additional Fieldpiece psychrometer readings (dry bulb, humidity)
/// HCI snoop captured Dec 21, 2025:
/// Call this for full data display
/// Screenshot values: Dry=69.0°F, Wet=55.7°F, RH=41.6%
/// Packet sample: 16b4 022d 029d 01bf 0133
Map<String, double> parseFieldpiecePsychrometerFull(List<int> rawData) {
  if (rawData.length < 22) {
    return {
      'wetBulb': double.nan,
      'dryBulb': double.nan,
      'humidity': double.nan
    };
  }

  final bytes = Uint8List.fromList(rawData);
  final byteData = ByteData.view(bytes.buffer);

  double wetBulbF = double.nan;
  double dryBulbF = double.nan;
  double humidity = double.nan;

  try {
    // Wet bulb at bytes 15-16 (CONFIRMED)
    // 0x022d = 557 ÷ 10 = 55.7°F ✓ matches screenshot
    final wetBulbRaw = byteData.getUint16(15, Endian.little);
    wetBulbF = wetBulbRaw / 10.0;

    // Dry bulb at bytes 12-13 (needs confirmation)
    // Screenshot shows 69.0°F, packet shows 0x16b4 = 5812
    // Try: 5812 / 10 = 581.2°F (no)
    //      5812 / 100 = 58.12°F (close to wet bulb, but should be higher)
    //      Try reading as little-endian: 0xb416 = 46102
    //      46102 / 1000 = 46.1°C = 114.9°F (too high)
    //      46102 / 100 = 461.02 (no)
    // Multiple interpretations needed
    if (rawData.length >= 14) {
      final dryBulbRaw = byteData.getUint16(12, Endian.little);
      
      // Try 1: divide by 10
      double dryBulbTest = dryBulbRaw / 10.0;
      if (dryBulbTest >= 0 && dryBulbTest <= 150) {
        dryBulbF = dryBulbTest;
      } else {
        // Try 2: convert to °C then to °F
        double dryBulbC = dryBulbRaw / 100.0;
        dryBulbF = dryBulbC * 9.0 / 5.0 + 32.0;
      }
    }

    // Humidity at bytes 20-21
    // Screenshot shows 41.6%, packet shows 0x0133 = 307
    // Try: 307 / 10 = 30.7% (close but not exact)
    //      307 / 7.38 ≈ 41.6% (possible but odd divisor)
    // Need more data to confirm exact formula
    if (rawData.length >= 22) {
      final humidityRaw = byteData.getUint16(20, Endian.little);
      
      // Try interpretation 1: direct %RH
      if (humidityRaw <= 100) {
        humidity = humidityRaw.toDouble();
      }
      // Try interpretation 2: scaled by 10
      else if (humidityRaw <= 1000) {
        humidity = humidityRaw / 10.0;
      }
      // Try interpretation 3: scaled by 100
      else {
        humidity = humidityRaw / 100.0;
      }
      
      // Sanity check
      if (humidity > 100 || humidity < 0) {
        humidity = double.nan;
      }
    }
  } catch (_) {}

  return {
    'wetBulb': wetBulbF,
    'dryBulb': dryBulbF,
    'humidity': humidity,
  };
}

/// Parse Fieldpiece SC680 Meter (FPCB)
/// Packet size: 30 bytes
/// This is a multi-function meter - value type depends on mode
double parseFieldpieceSC680(List<int> rawData) {
  if (rawData.length < 20) return double.nan;

  // Placeholder - SC680 is a multi-meter (amps, volts, ohms, etc.)
  // Need capture data showing different modes to decode
  final bytes = Uint8List.fromList(rawData);
  final byteData = ByteData.view(bytes.buffer);

  try {
    // Try int16 LE at bytes 15-16 divided by 10 (common for amp readings)
    if (rawData.length >= 17) {
      final valueRaw = byteData.getInt16(15, Endian.little);
      final value = valueRaw / 10.0;
      // Sanity check for amp readings (0-600A typical max)
      if (value >= 0 && value <= 600) {
        return value;
      }
    }
  } catch (_) {}

  return double.nan;
}

/// Extract battery level from Fieldpiece manufacturer data
/// Byte 9 appears to contain battery status (0x20 = good)
/// Returns battery percentage (0-100) or null if unable to determine
int? getFieldpieceBatteryLevel(List<int> manufacturerData) {
  if (manufacturerData.length < 10) return null;
  
  // Byte 9: Battery indicator
  // From HCI analysis: 0x20 = good battery
  // Need more samples to determine exact scale
  final batteryByte = manufacturerData[9];
  
  // Hypothesis: 0x20 (32 decimal) = 100%?
  // Or is it a flags byte where 0x20 bit means "battery good"?
  // For now, return rough estimate based on observed value
  if (batteryByte >= 0x20) {
    return 100; // Good battery
  } else if (batteryByte >= 0x10) {
    return 50; // Medium battery
  } else if (batteryByte > 0) {
    return 20; // Low battery
  }
  
  return null;
}

/// Extract model number from Fieldpiece manufacturer data
/// Bytes 6-7 contain model number (little-endian uint16)
/// Returns model number (e.g., 8975, 2975, 5699) or null if unable to determine
int? getFieldpieceModelNumber(List<int> manufacturerData) {
  if (manufacturerData.length < 8) return null;
  
  try {
    final bytes = Uint8List.fromList(manufacturerData.sublist(6, 8));
    final byteData = ByteData.view(bytes.buffer);
    return byteData.getUint16(0, Endian.little);
  } catch (_) {
    return null;
  }
}

/// Get device type name from Fieldpiece device code
/// Bytes 2-3 contain ASCII device type code
String getFieldpieceDeviceTypeName(List<int> manufacturerData) {
  if (manufacturerData.length < 4) return 'Unknown';
  
  final deviceCode = String.fromCharCodes(manufacturerData.sublist(2, 4));
  
  switch (deviceCode) {
    case 'BF':
      return 'Temperature Clamp';
    case 'BG':
      return 'Pressure Probe';
    case 'BH':
      return 'Psychrometer';
    case 'CB':
      return 'SC680 Meter';
    default:
      return 'Unknown ($deviceCode)';
  }
}

/// Helper to match byte pattern at offset
bool _matchesPattern(List<int> data, int offset, List<int> pattern) {
  if (offset + pattern.length > data.length) return false;
  for (int i = 0; i < pattern.length; i++) {
    if (data[offset + i] != pattern[i]) return false;
  }
  return true;
}

/// Convert raw bytes to hex string for debugging
String bytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}
