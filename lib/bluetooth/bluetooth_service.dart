import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Singleton Bluetooth service for managing HVAC tool connections.
/// Handles scanning, connecting, and data streaming from BLE devices.
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  // Stream controllers for broadcasting device events
  final _connectedDevicesController =
      StreamController<List<BluetoothDevice>>.broadcast();
  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  final _isScanning = StreamController<bool>.broadcast();

  // Currently connected devices
  final List<BluetoothDevice> _connectedDevices = [];

  // Subscriptions for cleanup
  final Map<String, StreamSubscription> _deviceSubscriptions = {};

  // Public streams
  Stream<List<BluetoothDevice>> get connectedDevices =>
      _connectedDevicesController.stream;
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;
  Stream<bool> get isScanning => _isScanning.stream;
  List<BluetoothDevice> get currentConnectedDevices =>
      List.unmodifiable(_connectedDevices);

  /// Initialize Bluetooth service
  Future<void> init({bool verbose = false}) async {
    if (verbose) {
      FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
    }

    // Listen for Bluetooth adapter state changes
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        // Bluetooth turned off - clear connections
        _connectedDevices.clear();
        _connectedDevicesController.add([]);
      }
    });

    // Listen for scan results
    FlutterBluePlus.scanResults.listen((results) {
      _scanResultsController.add(results);
    });

    // Listen for scanning state
    FlutterBluePlus.isScanning.listen((scanning) {
      _isScanning.add(scanning);
    });
  }

  /// Check if Bluetooth is available and on
  Future<bool> isBluetoothAvailable() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  /// Request Bluetooth to be turned on (Android only)
  Future<void> requestBluetoothOn() async {
    await FlutterBluePlus.turnOn();
  }

  /// Start scanning for HVAC tools
  /// Filters by known service UUIDs if provided
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
    List<Guid>? serviceUuids,
  }) async {
    if (!await isBluetoothAvailable()) {
      throw BluetoothException('Bluetooth is not available');
    }

    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: serviceUuids ?? [],
      androidUsesFineLocation: true,
    );
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connect to a device
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Monitor connection state
      final subscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          if (!_connectedDevices.contains(device)) {
            _connectedDevices.add(device);
            _connectedDevicesController.add(List.from(_connectedDevices));
          }
        } else if (state == BluetoothConnectionState.disconnected) {
          _connectedDevices.remove(device);
          _connectedDevicesController.add(List.from(_connectedDevices));
          _deviceSubscriptions[device.remoteId.str]?.cancel();
          _deviceSubscriptions.remove(device.remoteId.str);
        }
      });

      _deviceSubscriptions[device.remoteId.str] = subscription;

      // Discover services after connection
      await device.discoverServices();
    } catch (e) {
      throw BluetoothException('Failed to connect: $e');
    }
  }

  /// Disconnect from a device
  Future<void> disconnectDevice(BluetoothDevice device) async {
    await device.disconnect();
    _connectedDevices.remove(device);
    _connectedDevicesController.add(List.from(_connectedDevices));
  }

  /// Reconnect to a previously paired device by ID (no scan needed)
  Future<BluetoothDevice?> reconnectById(String remoteId) async {
    try {
      final device = BluetoothDevice.fromId(remoteId);
      await connectToDevice(device);
      return device;
    } catch (e) {
      return null;
    }
  }

  /// Get all GATT services for a connected device (for admin sniffer)
  Future<List<BluetoothService_Info>> discoverServicesDetailed(
      BluetoothDevice device) async {
    final services = await device.discoverServices();
    final result = <BluetoothService_Info>[];

    for (final service in services) {
      final characteristics = <CharacteristicInfo>[];

      for (final char in service.characteristics) {
        characteristics.add(CharacteristicInfo(
          uuid: char.uuid.toString(),
          properties: CharacteristicProperties(
            read: char.properties.read,
            write: char.properties.write,
            writeWithoutResponse: char.properties.writeWithoutResponse,
            notify: char.properties.notify,
            indicate: char.properties.indicate,
          ),
        ));
      }

      result.add(BluetoothService_Info(
        uuid: service.uuid.toString(),
        characteristics: characteristics,
      ));
    }

    return result;
  }

  /// Subscribe to characteristic notifications
  Future<Stream<List<int>>> subscribeToCharacteristic(
    BluetoothDevice device,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() ==
              characteristicUuid.toLowerCase()) {
            if (char.properties.notify || char.properties.indicate) {
              await char.setNotifyValue(true);
              return char.onValueReceived;
            }
          }
        }
      }
    }

    throw BluetoothException(
        'Characteristic not found or does not support notifications');
  }

  /// Read characteristic value
  Future<List<int>> readCharacteristic(
    BluetoothDevice device,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() ==
              characteristicUuid.toLowerCase()) {
            if (char.properties.read) {
              return await char.read();
            }
          }
        }
      }
    }

    throw BluetoothException(
        'Characteristic not found or does not support read');
  }

  /// Cleanup
  void dispose() {
    for (final sub in _deviceSubscriptions.values) {
      sub.cancel();
    }
    _deviceSubscriptions.clear();
    _connectedDevicesController.close();
    _scanResultsController.close();
    _isScanning.close();
  }
}

/// Custom exception for Bluetooth errors
class BluetoothException implements Exception {
  final String message;
  BluetoothException(this.message);

  @override
  String toString() => 'BluetoothException: $message';
}

/// Service info for admin sniffer view
class BluetoothService_Info {
  final String uuid;
  final List<CharacteristicInfo> characteristics;

  BluetoothService_Info({required this.uuid, required this.characteristics});
}

/// Characteristic info for admin sniffer view
class CharacteristicInfo {
  final String uuid;
  final CharacteristicProperties properties;

  CharacteristicInfo({required this.uuid, required this.properties});
}

/// Characteristic properties
class CharacteristicProperties {
  final bool read;
  final bool write;
  final bool writeWithoutResponse;
  final bool notify;
  final bool indicate;

  CharacteristicProperties({
    required this.read,
    required this.write,
    required this.writeWithoutResponse,
    required this.notify,
    required this.indicate,
  });
}
