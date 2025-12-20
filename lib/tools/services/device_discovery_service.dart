import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'device_registry.dart';

/// Discovered device with its profile info
class DiscoveredDevice {
  final ble.ScanResult scanResult;
  final DeviceProfile profile;
  final String displayName;
  final String deviceType;

  DiscoveredDevice({
    required this.scanResult,
    required this.profile,
    required this.displayName,
    required this.deviceType,
  });

  String get deviceId => scanResult.device.remoteId.str;
  ble.BluetoothDevice get device => scanResult.device;
  int get rssi => scanResult.rssi;
}

/// Service for auto-discovering compatible HVAC devices
class DeviceDiscoveryService {
  static final DeviceDiscoveryService _instance =
      DeviceDiscoveryService._internal();
  factory DeviceDiscoveryService() => _instance;
  DeviceDiscoveryService._internal();

  final DeviceRegistry _registry = DeviceRegistry();

  bool _isScanning = false;
  StreamSubscription? _scanSubscription;
  final _discoveredDevicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  // Current discovered devices
  final List<DiscoveredDevice> _discoveredDevices = [];

  /// Stream of discovered compatible devices
  Stream<List<DiscoveredDevice>> get discoveredDevices =>
      _discoveredDevicesController.stream;

  /// Current list of discovered devices
  List<DiscoveredDevice> get currentDiscoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  /// Whether currently scanning
  bool get isScanning => _isScanning;

  /// Start scanning for compatible devices
  Future<List<DiscoveredDevice>> scanForDevices({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_isScanning) return _discoveredDevices;

    _isScanning = true;
    _discoveredDevices.clear();

    // Check if Bluetooth is on
    final adapterState = await ble.FlutterBluePlus.adapterState.first;
    if (adapterState != ble.BluetoothAdapterState.on) {
      _isScanning = false;
      return [];
    }

    final completer = Completer<List<DiscoveredDevice>>();

    _scanSubscription = ble.FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final name = result.device.platformName;
        if (name.isEmpty) continue;

        // Check if this is a known device type
        final profile = _registry.identifyByName(name);
        if (profile == null) continue;

        // Check if already discovered
        final alreadyFound = _discoveredDevices
            .any((d) => d.deviceId == result.device.remoteId.str);
        if (alreadyFound) continue;

        // Add to discovered list
        final discovered = DiscoveredDevice(
          scanResult: result,
          profile: profile,
          displayName: _getDisplayName(name, profile),
          deviceType: _getDeviceTypeName(profile.type),
        );
        _discoveredDevices.add(discovered);
        _discoveredDevicesController.add(_discoveredDevices);
      }
    });

    // Start the scan
    try {
      await ble.FlutterBluePlus.startScan(timeout: timeout);
    } catch (e) {
      print('[Discovery] Scan error: $e');
    }

    // Wait for scan to complete
    await Future.delayed(timeout + const Duration(milliseconds: 500));

    await stopScan();
    completer.complete(_discoveredDevices);

    return completer.future;
  }

  /// Stop scanning
  Future<void> stopScan() async {
    _isScanning = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    try {
      await ble.FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore
    }
  }

  /// Get user-friendly display name
  String _getDisplayName(String rawName, DeviceProfile profile) {
    final nameLower = rawName.toLowerCase();

    // Testo probes - format nicely
    if (nameLower.contains('t115')) {
      // Extract serial number if present (format: "T115i SN:12345678")
      final snMatch =
          RegExp(r'sn[:\s]*(\d+)', caseSensitive: false).firstMatch(rawName);
      if (snMatch != null) {
        return 'Testo T115i (${snMatch.group(1)})';
      }
      return 'Testo T115i Temperature Probe';
    }
    if (nameLower.contains('t549')) {
      final snMatch =
          RegExp(r'sn[:\s]*(\d+)', caseSensitive: false).firstMatch(rawName);
      if (snMatch != null) {
        return 'Testo T549i (${snMatch.group(1)})';
      }
      return 'Testo T549i Pressure Probe';
    }
    if (nameLower.contains('t550')) {
      return 'Testo T550i Manifold';
    }

    // Wey-Tek scale
    if (nameLower == 'scale' ||
        nameLower.contains('weytek') ||
        nameLower.contains('wey')) {
      return 'Wey-Tek HD Scale';
    }

    // CCS
    if (nameLower.contains('ccs')) {
      return 'CCS Airflow Meter';
    }

    // Fallback to profile name
    return profile.name;
  }

  /// Get device type display name
  String _getDeviceTypeName(HvacDeviceType type) {
    switch (type) {
      case HvacDeviceType.temperatureProbe:
        return 'Temperature';
      case HvacDeviceType.pressureProbe:
        return 'Pressure';
      case HvacDeviceType.refrigerantScale:
        return 'Scale';
      case HvacDeviceType.airflowMeter:
        return 'Airflow';
      case HvacDeviceType.refrigerantGauge:
        return 'Gauge';
      case HvacDeviceType.clampMeter:
        return 'Electrical';
      case HvacDeviceType.vacuumGauge:
        return 'Vacuum';
      case HvacDeviceType.unknown:
        return 'Device';
    }
  }

  void dispose() {
    _scanSubscription?.cancel();
    _discoveredDevicesController.close();
  }
}
