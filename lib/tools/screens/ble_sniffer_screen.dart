import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../bluetooth/bluetooth_service.dart';
import '../services/device_registry.dart';
import '../services/ble_sniff_upload_service.dart';
import 'ble_sniffer_settings_screen.dart';

/// Admin-only BLE Sniffer screen for debugging HVAC tool protocols.
/// Allows scanning, connecting, and viewing raw GATT data.
class BleSnifferScreen extends StatefulWidget {
  const BleSnifferScreen({super.key});

  @override
  State<BleSnifferScreen> createState() => _BleSnifferScreenState();
}

class _BleSnifferScreenState extends State<BleSnifferScreen> {
  final BluetoothService _bleService = BluetoothService();
  final BleSniffUploadService _uploadService = BleSniffUploadService();

  bool _isScanning = false;
  bool _isConnecting = false;
  List<ble.ScanResult> _scanResults = [];
  ble.BluetoothDevice? _connectedDevice;
  List<ble.BluetoothService> _services = [];
  final List<_LogEntry> _logEntries = [];
  final ScrollController _logScrollController = ScrollController();

  // Track discovered data characteristics for profile generation
  String? _selectedServiceUuid;
  String? _selectedCharUuid;
  String _detectedUnit = '°F'; // Default unit guess
  bool _showDataInterpreter = true;

  // Session persistence
  Box? _sniffBox;
  String _currentSessionId = '';
  List<Map<String, dynamic>> _savedSessions = [];
  bool _showHistory = false;

  // Filter options
  bool _hideAppleDevices =
      true; // Hide Apple devices by default (iPhones, AirPods, etc)

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  final Map<String, StreamSubscription> _notifySubscriptions = {};

  // Device Information Service (0x180a) - real names from device
  String? _deviceManufacturer; // Char 0x2a29
  String? _deviceModelNumber; // Char 0x2a24
  String? _deviceSerialNumber; // Char 0x2a25
  String? _deviceFirmwareRev; // Char 0x2a26
  String? _deviceHardwareRev; // Char 0x2a27

  @override
  void initState() {
    super.initState();
    _initBle();
    _initStorage();
  }

  Future<void> _initStorage() async {
    try {
      // Initialize Hive with app documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      if (!Hive.isBoxOpen('ble_sniff_sessions')) {
        Hive.init(appDocDir.path);
      }
      _sniffBox = await Hive.openBox('ble_sniff_sessions');
      _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      _loadSavedSessions();
      
      // Load upload service settings
      await _uploadService.loadSettings();
      
      // Auto-upload any unsynced sessions on startup
      _autoUploadUnsyncedSessions();
    } catch (e) {
      print('[BLE Sniffer] Storage init error: $e');
    }
  }

  void _loadSavedSessions() {
    if (_sniffBox == null) return;
    final sessions = <Map<String, dynamic>>[];
    for (final key in _sniffBox!.keys) {
      final data = _sniffBox!.get(key);
      if (data != null) {
        try {
          sessions.add(Map<String, dynamic>.from(jsonDecode(data)));
        } catch (_) {}
      }
    }
    // Sort by timestamp descending (newest first)
    sessions
        .sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
    setState(() {
      _savedSessions = sessions;
    });
  }

  /// Auto-upload unsynced sessions in the background
  Future<void> _autoUploadUnsyncedSessions() async {
    if (_sniffBox == null) return;
    
    try {
      final count = await _uploadService.uploadUnsyncedSessions(_sniffBox!);
      if (count > 0) {
        _addLog('Auto-uploaded $count unsynced session(s) to Firebase', type: 'success');
      }
    } catch (e) {
      debugPrint('[BLE Sniffer] Auto-upload failed: $e');
    }
  }

  /// Auto-save current session to local storage with FULL BLE data
  Future<void> _autoSaveSession() async {
    if (_sniffBox == null || (_logEntries.isEmpty && _scanResults.isEmpty))
      return;

    final sessionData = {
      'id': _currentSessionId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'date': DateTime.now().toIso8601String(),
      'connectedDevice': _connectedDevice != null
          ? {
              'name': _connectedDevice!.platformName,
              'mac': _connectedDevice!.remoteId.str,
            }
          : null,
      'devices': _scanResults.map((r) {
        final adv = r.advertisementData;
        return {
          'name': r.device.platformName.isNotEmpty
              ? r.device.platformName
              : adv.advName,
          'localName': adv.advName,
          'mac': r.device.remoteId.str,
          'rssi': r.rssi,
          'txPower': adv.txPowerLevel,
          'connectable': adv.connectable,
          'services': adv.serviceUuids.map((u) => u.toString()).toList(),
          'manufacturerData': adv.manufacturerData.map((k, v) => MapEntry(
              k.toString(),
              v.map((b) => b.toRadixString(16).padLeft(2, '0')).join())),
          'serviceData': adv.serviceData.map((k, v) => MapEntry(k.toString(),
              v.map((b) => b.toRadixString(16).padLeft(2, '0')).join())),
        };
      }).toList(),
      'logs': _logEntries
          .map((e) => {
                'time': e.timestamp.toIso8601String(),
                'type': e.type,
                'msg': e.message,
              })
          .toList(),
      'deviceCount': _scanResults.length,
      'logCount': _logEntries.length,
    };

    await _sniffBox!.put(_currentSessionId, jsonEncode(sessionData));
    _loadSavedSessions();
    
    // Auto-upload if enabled
    _uploadService.autoUploadSessionIfEnabled(
      _sniffBox!,
      _currentSessionId,
      sessionData,
    ).then((uploaded) {
      if (uploaded) {
        _addLog('Session auto-uploaded to Firebase', type: 'success');
      }
    }).catchError((error, stackTrace) {
      _addLog('Failed to auto-upload session: $error', type: 'error');
    });
  }

  StreamSubscription? _isScanningSubscription;

  Future<void> _initBle() async {
    await _bleService.init(verbose: true);

    _scanSubscription = ble.FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      // Sort by signal strength (strongest first)
      final sorted = List<ble.ScanResult>.from(results);
      sorted.sort((a, b) => b.rssi.compareTo(a.rssi));
      setState(() {
        _scanResults = sorted;
      });
    });

    _isScanningSubscription = ble.FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return;
      setState(() {
        _isScanning = scanning;
      });
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _connectionSubscription?.cancel();
    for (final sub in _notifySubscriptions.values) {
      sub.cancel();
    }
    _logScrollController.dispose();
    super.dispose();
  }

  void _addLog(String message, {String type = 'info'}) {
    if (!mounted) return;
    setState(() {
      _logEntries.add(_LogEntry(
        timestamp: DateTime.now(),
        message: message,
        type: type,
      ));
    });

    // Auto-save every 10 log entries
    if (_logEntries.length % 10 == 0) {
      _autoSaveSession();
    }

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startScan() async {
    // Start a new session for each scan
    _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _addLog('Starting BLE scan...', type: 'action');
    setState(() {
      _scanResults = [];
    });

    try {
      await ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      _addLog('Scan error: $e', type: 'error');
    }
  }

  Future<void> _stopScan() async {
    await ble.FlutterBluePlus.stopScan();
    _addLog('Scan stopped. Found ${_scanResults.length} devices.',
        type: 'info');
    // Auto-save when scan completes
    _autoSaveSession();
  }

  Future<void> _connectToDevice(ble.BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
    });

    _addLog('Connecting to ${device.platformName}...', type: 'action');

    try {
      await device.connect(timeout: const Duration(seconds: 15));

      _connectionSubscription = device.connectionState.listen((state) {
        if (state == ble.BluetoothConnectionState.disconnected) {
          _addLog('Device disconnected', type: 'warning');
          setState(() {
            _connectedDevice = null;
            _services = [];
            // Clear device info
            _deviceManufacturer = null;
            _deviceModelNumber = null;
            _deviceSerialNumber = null;
            _deviceFirmwareRev = null;
            _deviceHardwareRev = null;
          });
        }
      });

      setState(() {
        _connectedDevice = device;
        _isConnecting = false;
      });

      _addLog('Connected! Discovering services...', type: 'success');
      await _discoverServices();
    } catch (e) {
      _addLog('Connection failed: $e', type: 'error');
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;

    try {
      final services = await _connectedDevice!.discoverServices();
      setState(() {
        _services = services;
      });

      _addLog('Found ${services.length} services:', type: 'info');
      for (final service in services) {
        _addLog('  Service: ${service.uuid}', type: 'data');
        for (final char in service.characteristics) {
          final props = <String>[];
          if (char.properties.read) props.add('R');
          if (char.properties.write) props.add('W');
          if (char.properties.notify) props.add('N');
          if (char.properties.indicate) props.add('I');
          _addLog('    Char: ${char.uuid} [${props.join(',')}]', type: 'data');
        }
      }

      // Auto-subscribe to all notify/indicate characteristics to capture live data
      _addLog('Auto-subscribing to all notify characteristics...',
          type: 'action');
      await _autoSubscribeAll();

      // Auto-read all readable characteristics
      _addLog('Auto-reading all readable characteristics...', type: 'action');
      await _autoReadAll();

      // Read Device Information Service to get real names
      await _readDeviceInfoService();
    } catch (e) {
      _addLog('Service discovery failed: $e', type: 'error');
    }
  }

  /// Auto-subscribe to ALL notify/indicate characteristics to capture live data
  Future<void> _autoSubscribeAll() async {
    for (final service in _services) {
      for (final char in service.characteristics) {
        if (char.properties.notify || char.properties.indicate) {
          final key = char.uuid.toString();
          if (_notifySubscriptions.containsKey(key)) continue;

          try {
            await char.setNotifyValue(true);
            _addLog('AUTO-SUBSCRIBED: ${char.uuid}', type: 'success');

            final sub = char.onValueReceived.listen((value) {
              final hex = _bytesToHex(value);
              _addLog('📡 DATA [${char.uuid}]:', type: 'notify');
              _addLog('  Hex: $hex', type: 'data');
              _addLog('  Raw: [${value.join(', ')}]', type: 'data');

              // Enhanced data interpretation
              if (value.isNotEmpty) {
                final ascii = _bytesToAscii(value);
                if (ascii.trim().isNotEmpty && !ascii.contains('�')) {
                  _addLog('  ASCII: $ascii', type: 'debug');
                }
              }
              if (value.length >= 2) {
                final bytes = Uint8List.fromList(value);
                final byteData = ByteData.view(bytes.buffer);
                final int16LE = byteData.getInt16(0, Endian.little);
                final int16BE = byteData.getInt16(0, Endian.big);
                _addLog(
                    '  int16 LE: $int16LE (÷10=${(int16LE / 10.0).toStringAsFixed(1)}, ÷100=${(int16LE / 100.0).toStringAsFixed(2)})',
                    type: 'debug');
                _addLog(
                    '  int16 BE: $int16BE (÷10=${(int16BE / 10.0).toStringAsFixed(1)}, ÷100=${(int16BE / 100.0).toStringAsFixed(2)})',
                    type: 'debug');
              }
              if (value.length >= 4) {
                final bytes = Uint8List.fromList(value);
                final byteData = ByteData.view(bytes.buffer);
                final float32LE = byteData.getFloat32(0, Endian.little);
                _addLog('  float32 LE: ${float32LE.toStringAsFixed(4)}',
                    type: 'debug');
              }
            });

            _notifySubscriptions[key] = sub;
          } catch (e) {
            _addLog('Subscribe failed ${char.uuid}: $e', type: 'error');
          }
          // Small delay to avoid overwhelming the device
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  }

  /// Auto-read ALL readable characteristics to capture static values
  Future<void> _autoReadAll() async {
    for (final service in _services) {
      for (final char in service.characteristics) {
        if (char.properties.read) {
          try {
            final value = await char.read();
            _addLog('📖 READ [${char.uuid}]:', type: 'data');
            _logDataInterpretations(value, char.uuid.toString());
          } catch (e) {
            _addLog('Read failed ${char.uuid}: $e', type: 'error');
          }
          // Small delay to avoid overwhelming the device
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    }
  }

  /// Read Device Information Service (0x180a) to get real manufacturer/model names
  /// Standard characteristics:
  /// - 0x2a29: Manufacturer Name
  /// - 0x2a24: Model Number
  /// - 0x2a25: Serial Number
  /// - 0x2a26: Firmware Revision
  /// - 0x2a27: Hardware Revision
  Future<void> _readDeviceInfoService() async {
    // Clear previous device info
    _deviceManufacturer = null;
    _deviceModelNumber = null;
    _deviceSerialNumber = null;
    _deviceFirmwareRev = null;
    _deviceHardwareRev = null;

    // Find Device Information Service (0x180a)
    ble.BluetoothService? deviceInfoService;
    for (final service in _services) {
      if (service.uuid.toString().toLowerCase().contains('180a')) {
        deviceInfoService = service;
        break;
      }
    }

    if (deviceInfoService == null) {
      _addLog('📋 Device Information Service (0x180a) not found', type: 'info');
      return;
    }

    _addLog('📋 Reading Device Information Service...', type: 'action');

    // Map of characteristic UUIDs to their names and storage
    final charMap = <String, String>{
      '2a29': 'Manufacturer Name',
      '2a24': 'Model Number',
      '2a25': 'Serial Number',
      '2a26': 'Firmware Revision',
      '2a27': 'Hardware Revision',
      '2a28': 'Software Revision',
      '2a50': 'PnP ID',
    };

    for (final char in deviceInfoService.characteristics) {
      final charUuid = char.uuid.toString().toLowerCase();
      // Extract the 4-char UUID part
      String shortUuid = charUuid;
      if (charUuid.contains('-')) {
        shortUuid = charUuid.substring(4, 8);
      }

      final charName = charMap[shortUuid];
      if (charName != null && char.properties.read) {
        try {
          final value = await char.read();
          final stringValue = String.fromCharCodes(value).trim();

          _addLog('  $charName: $stringValue', type: 'success');

          // Store in state variables
          switch (shortUuid) {
            case '2a29':
              _deviceManufacturer = stringValue;
              break;
            case '2a24':
              _deviceModelNumber = stringValue;
              break;
            case '2a25':
              _deviceSerialNumber = stringValue;
              break;
            case '2a26':
              _deviceFirmwareRev = stringValue;
              break;
            case '2a27':
              _deviceHardwareRev = stringValue;
              break;
          }
        } catch (e) {
          _addLog('  Failed to read $charName: $e', type: 'error');
        }
        await Future.delayed(const Duration(milliseconds: 30));
      }
    }

    // Log summary if any info found
    if (_deviceManufacturer != null || _deviceModelNumber != null) {
      _addLog(
        '📋 DEVICE: ${_deviceManufacturer ?? "?"} ${_deviceModelNumber ?? ""}',
        type: 'success',
      );
      if (_deviceFirmwareRev != null) {
        _addLog('   Firmware: $_deviceFirmwareRev', type: 'info');
      }
      setState(() {}); // Trigger UI update to show device info
    }
  }

  Future<void> _readCharacteristic(ble.BluetoothCharacteristic char) async {
    try {
      _addLog('Reading ${char.uuid}...', type: 'action');
      final value = await char.read();
      _logDataInterpretations(value, char.uuid.toString());
    } catch (e) {
      _addLog('Read failed: $e', type: 'error');
    }
  }

  /// Log all possible data interpretations for debugging
  void _logDataInterpretations(List<int> value, String charUuid) {
    final hex = _bytesToHex(value);
    final ascii = _bytesToAscii(value);

    _addLog('  Hex: $hex', type: 'data');
    _addLog('  Raw bytes: [${value.join(', ')}]', type: 'data');
    _addLog('  ASCII: $ascii', type: 'data');

    if (_showDataInterpreter && value.isNotEmpty) {
      _addLog('  === Data Interpretations ===', type: 'debug');

      // Single byte interpretations
      if (value.length >= 1) {
        _addLog('  uint8[0]: ${value[0]}', type: 'debug');
        _addLog('  int8[0]: ${value[0] > 127 ? value[0] - 256 : value[0]}',
            type: 'debug');
      }

      // 2-byte interpretations
      if (value.length >= 2) {
        final bytes = Uint8List.fromList(value);
        final byteData = ByteData.view(bytes.buffer);

        final uint16LE = byteData.getUint16(0, Endian.little);
        final uint16BE = byteData.getUint16(0, Endian.big);
        final int16LE = byteData.getInt16(0, Endian.little);
        final int16BE = byteData.getInt16(0, Endian.big);

        _addLog('  uint16 LE: $uint16LE', type: 'debug');
        _addLog('  uint16 BE: $uint16BE', type: 'debug');
        _addLog('  int16 LE: $int16LE', type: 'debug');
        _addLog('  int16 BE: $int16BE', type: 'debug');

        // Common divisors for sensor data
        _addLog('  ÷10 LE: ${int16LE / 10.0}', type: 'debug');
        _addLog('  ÷100 LE: ${int16LE / 100.0}', type: 'debug');
        _addLog('  ÷10 BE: ${int16BE / 10.0}', type: 'debug');
        _addLog('  ÷100 BE: ${int16BE / 100.0}', type: 'debug');
      }

      // 4-byte interpretations
      if (value.length >= 4) {
        final bytes = Uint8List.fromList(value);
        final byteData = ByteData.view(bytes.buffer);

        final uint32LE = byteData.getUint32(0, Endian.little);
        final int32LE = byteData.getInt32(0, Endian.little);
        final float32LE = byteData.getFloat32(0, Endian.little);

        _addLog('  uint32 LE: $uint32LE', type: 'debug');
        _addLog('  int32 LE: $int32LE', type: 'debug');
        _addLog('  float32 LE: ${float32LE.toStringAsFixed(4)}', type: 'debug');
      }
    }

    // Track this characteristic for profile generation
    setState(() {
      _selectedCharUuid = charUuid;
    });
  }

  Future<void> _toggleNotify(ble.BluetoothCharacteristic char) async {
    final key = char.uuid.toString();

    if (_notifySubscriptions.containsKey(key)) {
      // Unsubscribe
      await char.setNotifyValue(false);
      _notifySubscriptions[key]?.cancel();
      _notifySubscriptions.remove(key);
      _addLog('Unsubscribed from ${char.uuid}', type: 'info');
      setState(() {});
    } else {
      // Subscribe
      try {
        await char.setNotifyValue(true);
        _addLog('Subscribed to ${char.uuid}', type: 'success');

        // Find service UUID for this characteristic
        for (final service in _services) {
          for (final c in service.characteristics) {
            if (c.uuid.toString() == key) {
              _selectedServiceUuid = service.uuid.toString();
              break;
            }
          }
        }
        _selectedCharUuid = key;

        final sub = char.onValueReceived.listen((value) {
          final hex = _bytesToHex(value);
          _addLog('NOTIFY $key:', type: 'notify');
          _addLog('  Hex: $hex', type: 'data');

          // Enhanced notify data interpretation
          if (_showDataInterpreter && value.length >= 2) {
            final bytes = Uint8List.fromList(value);
            final byteData = ByteData.view(bytes.buffer);
            final int16LE = byteData.getInt16(0, Endian.little);
            final div10 = int16LE / 10.0;
            final div100 = int16LE / 100.0;
            _addLog(
                '  int16÷10: ${div10.toStringAsFixed(1)} | ÷100: ${div100.toStringAsFixed(2)}',
                type: 'debug');

            // If 4+ bytes, show additional values
            if (value.length >= 4) {
              final int16LE_2 = byteData.getInt16(2, Endian.little);
              _addLog(
                  '  [2-3] int16÷10: ${(int16LE_2 / 10.0).toStringAsFixed(1)}',
                  type: 'debug');
            }
          }
        });

        _notifySubscriptions[key] = sub;
        setState(() {});
      } catch (e) {
        _addLog('Subscribe failed: $e', type: 'error');
      }
    }
  }

  Future<void> _disconnect() async {
    if (_connectedDevice == null) return;

    _addLog('Disconnecting...', type: 'action');

    for (final sub in _notifySubscriptions.values) {
      sub.cancel();
    }
    _notifySubscriptions.clear();

    await _connectedDevice!.disconnect();

    // Auto-save session when disconnecting
    await _autoSaveSession();

    setState(() {
      _connectedDevice = null;
      _services = [];
      // Clear device info
      _deviceManufacturer = null;
      _deviceModelNumber = null;
      _deviceSerialNumber = null;
      _deviceFirmwareRev = null;
      _deviceHardwareRev = null;
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearLogs() {
    setState(() {
      _logEntries.clear();
    });
  }

  void _exportLogs() {
    final buffer = StringBuffer();
    for (final entry in _logEntries) {
      buffer.writeln('[${entry.timestamp.toIso8601String()}] ${entry.message}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  /// Share logs via system share sheet (email, messages, files, etc.)
  Future<void> _shareLogs() async {
    if (_logEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No logs to share'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('=== BLE Sniffer Log ===');
    buffer.writeln('Date: ${DateTime.now().toIso8601String()}');
    if (_connectedDevice != null) {
      buffer.writeln('Device: ${_connectedDevice!.platformName}');
      buffer.writeln('MAC: ${_connectedDevice!.remoteId.str}');
    }
    buffer.writeln('');
    buffer.writeln('--- Discovered Devices ---');
    for (final result in _scanResults) {
      final name = result.device.platformName.isNotEmpty
          ? result.device.platformName
          : 'Unknown';
      buffer.writeln(
          '$name (${result.device.remoteId.str}) RSSI: ${result.rssi}');
    }
    buffer.writeln('');
    buffer.writeln('--- Log Entries ---');
    for (final entry in _logEntries) {
      buffer.writeln(
          '[${entry.timestamp.toIso8601String()}] [${entry.type}] ${entry.message}');
    }

    try {
      await Share.share(
        buffer.toString(),
        subject:
            'BLE Sniffer Log - ${DateTime.now().toString().split('.').first}',
      );
    } catch (e) {
      _addLog('Share failed: $e', type: 'error');
    }
  }

  /// Sync sniff data to Firebase for later analysis on desktop
  Future<void> _syncToFirebase() async {
    if (_logEntries.isEmpty && _scanResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to sync'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    _addLog('Syncing to Firebase...', type: 'action');

    try {
      final timestamp = DateTime.now();
      final docId = 'sniff_${timestamp.millisecondsSinceEpoch}';

      // Build device list with all available info
      final deviceList = _scanResults.map((result) {
        final adv = result.advertisementData;
        return {
          'name': result.device.platformName.isNotEmpty
              ? result.device.platformName
              : adv.advName,
          'mac': result.device.remoteId.str,
          'rssi': result.rssi,
          'txPower': adv.txPowerLevel,
          'serviceUuids': adv.serviceUuids.map((u) => u.toString()).toList(),
          'manufacturerData': adv.manufacturerData.map((k, v) => MapEntry(
              k.toString(),
              v.map((b) => b.toRadixString(16).padLeft(2, '0')).join())),
          'connectable': adv.connectable,
        };
      }).toList();

      // Build log entries
      final logs = _logEntries
          .map((entry) => {
                'timestamp': entry.timestamp.toIso8601String(),
                'type': entry.type,
                'message': entry.message,
              })
          .toList();

      // Connected device services
      List<Map<String, dynamic>>? connectedServices;
      if (_connectedDevice != null && _services.isNotEmpty) {
        connectedServices = _services
            .map((service) => {
                  'uuid': service.uuid.toString(),
                  'characteristics': service.characteristics
                      .map((char) => {
                            'uuid': char.uuid.toString(),
                            'properties': {
                              'read': char.properties.read,
                              'write': char.properties.write,
                              'writeNoResponse':
                                  char.properties.writeWithoutResponse,
                              'notify': char.properties.notify,
                              'indicate': char.properties.indicate,
                            },
                          })
                      .toList(),
                })
            .toList();
      }

      await FirebaseFirestore.instance
          .collection('ble_sniff_logs')
          .doc(docId)
          .set({
        'timestamp': FieldValue.serverTimestamp(),
        'captureDate': timestamp.toIso8601String(),
        'connectedDevice': _connectedDevice != null
            ? {
                'name': _connectedDevice!.platformName,
                'mac': _connectedDevice!.remoteId.str,
              }
            : null,
        'devices': deviceList,
        'logs': logs,
        'services': connectedServices,
        'deviceCount': _scanResults.length,
        'logCount': _logEntries.length,
      });

      _addLog('Synced to Firebase: $docId', type: 'success');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Synced ${_logEntries.length} logs & ${_scanResults.length} devices'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      _addLog('Sync failed: $e', type: 'error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Generate device profile code from sniffed data
  void _generateProfile() {
    if (_connectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to a device first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    _showProfileGenerator();
  }

  void _showProfileGenerator() {
    final deviceName = _connectedDevice?.platformName ?? 'Unknown';
    final nameController = TextEditingController(
        text:
            deviceName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase());
    final displayNameController = TextEditingController(text: deviceName);
    String selectedType = 'temperatureProbe';
    String selectedUnit = _detectedUnit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Generate Device Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Profile Key
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Profile Key',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    hintText: 'e.g., testo_temp_probe',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Display Name
                TextField(
                  controller: displayNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Device Type dropdown
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: AppColors.surfaceLight,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Device Type',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'temperatureProbe',
                        child: Text('Temperature Probe')),
                    DropdownMenuItem(
                        value: 'pressureProbe', child: Text('Pressure Probe')),
                    DropdownMenuItem(
                        value: 'refrigerantGauge',
                        child: Text('Refrigerant Gauge')),
                    DropdownMenuItem(
                        value: 'refrigerantScale',
                        child: Text('Refrigerant Scale')),
                    DropdownMenuItem(
                        value: 'airflowMeter', child: Text('Airflow Meter')),
                    DropdownMenuItem(
                        value: 'clampMeter', child: Text('Clamp Meter')),
                    DropdownMenuItem(
                        value: 'vacuumGauge', child: Text('Vacuum Gauge')),
                  ],
                  onChanged: (v) => setModalState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),

                // Unit dropdown
                DropdownButtonFormField<String>(
                  value: selectedUnit,
                  dropdownColor: AppColors.surfaceLight,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: '°F', child: Text('°F (Temperature)')),
                    DropdownMenuItem(
                        value: '°C', child: Text('°C (Temperature)')),
                    DropdownMenuItem(
                        value: 'psig', child: Text('psig (Pressure)')),
                    DropdownMenuItem(
                        value: 'bar', child: Text('bar (Pressure)')),
                    DropdownMenuItem(value: 'lbs', child: Text('lbs (Weight)')),
                    DropdownMenuItem(value: 'kg', child: Text('kg (Weight)')),
                    DropdownMenuItem(
                        value: 'CFM', child: Text('CFM (Airflow)')),
                    DropdownMenuItem(value: 'A', child: Text('Amps (Current)')),
                    DropdownMenuItem(
                        value: 'micron', child: Text('micron (Vacuum)')),
                  ],
                  onChanged: (v) => setModalState(() => selectedUnit = v!),
                ),
                const SizedBox(height: 12),

                // Selected UUIDs display
                if (_selectedServiceUuid != null || _selectedCharUuid != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detected UUIDs:',
                          style: TextStyle(
                              color: AppColors.primaryCyan, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        if (_selectedServiceUuid != null)
                          Text(
                            'Service: $_selectedServiceUuid',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontFamily: 'monospace'),
                          ),
                        if (_selectedCharUuid != null)
                          Text(
                            'Char: $_selectedCharUuid',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontFamily: 'monospace'),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // Generate button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final code = _buildProfileCode(
                        key: nameController.text,
                        displayName: displayNameController.text,
                        type: selectedType,
                        unit: selectedUnit,
                        serviceUuid: _selectedServiceUuid,
                        charUuid: _selectedCharUuid,
                      );
                      Clipboard.setData(ClipboardData(text: code));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile code copied to clipboard!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      _addLog(
                          'Generated profile code for ${displayNameController.text}',
                          type: 'success');
                    },
                    icon: const Icon(Icons.code),
                    label: const Text('Generate & Copy Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCyan,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildProfileCode({
    required String key,
    required String displayName,
    required String type,
    required String unit,
    String? serviceUuid,
    String? charUuid,
  }) {
    final svcUuid = serviceUuid ?? '0000xxxx-0000-1000-8000-00805f9b34fb';
    final dataUuid = charUuid ?? '0000xxxx-0000-1000-8000-00805f9b34fb';

    return '''
// Add to device_registry.dart _profiles map:

'$key': DeviceProfile(
  name: '$displayName',
  manufacturer: HvacManufacturer.testo, // TODO: Update manufacturer
  type: HvacDeviceType.$type,
  serviceUuids: ['$svcUuid'],
  dataCharacteristicUuid: '$dataUuid',
  unit: '$unit',
  parseReading: _parse${_toPascalCase(key)},
),

// Add parsing function:

/// Parse $displayName reading from raw BLE data
double _parse${_toPascalCase(key)}(List<int> rawData) {
  if (rawData.length < 2) return 0.0;
  
  final bytes = Uint8List.fromList(rawData);
  final byteData = ByteData.view(bytes.buffer);
  
  try {
    // TODO: Adjust based on actual data format observed in sniffer
    final rawValue = byteData.getInt16(0, Endian.little);
    return rawValue / 10.0; // Adjust divisor as needed
  } catch (e) {
    return 0.0;
  }
}
''';
  }

  String _toPascalCase(String input) {
    return input
        .split('_')
        .map((word) => word.isEmpty
            ? ''
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join('');
  }

  void _toggleDataInterpreter() {
    setState(() {
      _showDataInterpreter = !_showDataInterpreter;
    });
    _addLog('Data interpreter ${_showDataInterpreter ? 'enabled' : 'disabled'}',
        type: 'info');
  }

  /// Write to a characteristic (for bidirectional testing)
  Future<void> _writeToCharacteristic(ble.BluetoothCharacteristic char) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Write to Characteristic',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              char.uuid.toString(),
              style: const TextStyle(
                  color: AppColors.primaryCyan,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Hex bytes (space separated)',
                hintText: 'e.g., 01 02 FF',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
            ),
            child: const Text('Write'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final bytes = result
            .split(' ')
            .where((s) => s.isNotEmpty)
            .map((s) => int.parse(s, radix: 16))
            .toList();

        _addLog('Writing ${_bytesToHex(bytes)} to ${char.uuid}...',
            type: 'action');

        if (char.properties.writeWithoutResponse) {
          await char.write(bytes, withoutResponse: true);
        } else {
          await char.write(bytes);
        }

        _addLog('Write successful!', type: 'success');
      } catch (e) {
        _addLog('Write failed: $e', type: 'error');
      }
    }
  }

  String _bytesToHex(List<int> bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  String _bytesToAscii(List<int> bytes) {
    return bytes
        .map((b) => b >= 32 && b <= 126 ? String.fromCharCode(b) : '.')
        .join();
  }

  /// Get best display name for connected device
  /// Prioritizes: Model from Device Info > advertised name > platform name
  String _getDisplayName() {
    if (_connectedDevice == null) return 'Unknown';

    // If we have a model number from Device Info Service, use that
    if (_deviceModelNumber != null && _deviceModelNumber!.isNotEmpty) {
      return _deviceModelNumber!;
    }

    // Otherwise use platform name (BLE advertised name)
    final name = _connectedDevice!.platformName;
    return name.isNotEmpty ? name : _connectedDevice!.remoteId.str;
  }

  /// Shorten UUID for display (e.g., 0000fff0-0000-1000-8000-00805f9b34fb -> fff0)
  String _shortenUuid(String uuid) {
    // Standard Bluetooth base UUID
    const baseUuid = '-0000-1000-8000-00805f9b34fb';
    if (uuid.toLowerCase().endsWith(baseUuid.toLowerCase()) &&
        uuid.startsWith('0000')) {
      // It's a standard 16-bit UUID, extract just the significant part
      return uuid.substring(4, 8);
    }
    // Return first 8 chars for custom UUIDs
    return uuid.length > 8 ? uuid.substring(0, 8) : uuid;
  }

  /// Get manufacturer name from manufacturer data
  String _getManufacturerName(Map<int, List<int>> manufacturerData) {
    if (manufacturerData.isEmpty) return '';

    // Bluetooth Company IDs - expanded HVAC tool list
    // See: https://www.bluetooth.com/specifications/assigned-numbers/company-identifiers/
    const companyIds = <int, String>{
      // Major tech companies
      0x0002: 'Intel',
      0x0006: 'Microsoft',
      0x000D: 'Texas Instruments',
      0x004C: 'Apple',
      0x0059: 'Nordic Semiconductor',
      0x0075: 'Samsung',
      0x00E0: 'Google',
      0x0131: 'Cypress',
      0x015D: 'Xiaomi',
      0x0157: 'Huawei',
      0x0171: 'Amazon',

      // HVAC Tool Manufacturers
      0x02E1: 'Testo AG', // Testo smart probes
      0x5046: 'Fieldpiece', // Fieldpiece tools (confirmed 0x5046 = "PF")
      0x038F: 'Fieldpiece (legacy)', // May be old ID
      0x0310: 'Yellow Jacket', // Yellow Jacket gauges
      0x02B3: 'Supco', // Supco diagnostics
      0x05A7: 'CPS Products', // CPS/AAB - ABM-200
      0x089A: 'Navac', // Navac recovery
      0x0806: 'Wey-Tek/Inficon', // Inficon/Wey-Tek scales
      0x0A55: 'WeatherFlow', // ABM-200 original mfr
      0x07D5: 'Parker Sporlan', // Parker Hannifin
      0x08A3: 'Mastercool', // Mastercool gauges
      0x0B2C: 'JB Industries', // JB Industries
      0x0C11: 'Robinair', // Robinair
      0x0C9E: 'Bacharach', // Gas detection
      0x0D27: 'UEi Test', // UEi instruments
      0x0E14: 'REFCO', // REFCO gauges
      0x0F08: 'Ritchie Eng', // Yellow Jacket parent
    };

    final entries = manufacturerData.entries.toList();
    final companyId = entries.first.key;
    // Raw data available if needed: entries.first.value

    final companyName = companyIds[companyId];
    if (companyName != null) {
      return companyName;
    }

    // Return hex company ID if unknown
    return 'Mfr: 0x${companyId.toRadixString(16).padLeft(4, '0').toUpperCase()}';
  }

  /// Look up manufacturer from MAC address OUI (first 3 bytes)
  /// This helps identify devices that don't advertise manufacturer data
  String _getMacOuiManufacturer(String macAddress) {
    // Extract OUI (first 3 octets)
    final parts = macAddress.split(':');
    if (parts.length < 3) return '';
    final oui = '${parts[0]}:${parts[1]}:${parts[2]}'.toUpperCase();

    // Common BLE chip manufacturers used in HVAC tools
    // OUI database: https://standards-oui.ieee.org/
    const ouiMap = {
      // Texas Instruments - Used by Fieldpiece, many HVAC tools
      '84:C6:92': 'Texas Instruments (Fieldpiece?)',
      '04:E9:E5': 'Texas Instruments',
      '34:B1:F7': 'Texas Instruments',
      '7C:EC:79': 'Texas Instruments',
      '98:07:2D': 'Texas Instruments',
      'B0:B4:48': 'Texas Instruments',
      'D4:F5:13': 'Texas Instruments',

      // Nordic Semiconductor - Testo, many sensors
      'C7:16:86': 'Nordic Semi (HVAC Sensor?)',
      'D5:26:21': 'Nordic Semi',
      'E7:25:7B': 'Nordic Semi',
      'F4:1B:F3': 'Nordic Semi',

      // Dialog/Renesas - Various IoT devices
      '80:EA:CA': 'Dialog Semi',

      // Espressif - ESP32 based devices
      '24:0A:C4': 'Espressif (ESP32)',
      '30:AE:A4': 'Espressif (ESP32)',
      'A4:CF:12': 'Espressif (ESP32)',

      // Silicon Labs - Used in some HVAC tools
      '00:0B:57': 'Silicon Labs',
      '84:2E:14': 'Silicon Labs',

      // Microchip
      '00:1E:C0': 'Microchip',
      'D8:80:39': 'Microchip',

      // STMicro - BlueNRG chips
      '02:80:E1': 'STMicro BlueNRG',

      // Murata (used in many Japanese tools)
      '44:D8:84': 'Murata',

      // Cypress/Infineon
      '00:A0:50': 'Cypress/Infineon',

      // Telink - Budget BLE chips
      'A4:C1:38': 'Telink Semi',

      // Realtek
      '00:E0:4C': 'Realtek',

      // Qualcomm/CSR
      '00:02:5B': 'Qualcomm/CSR',
    };

    return ouiMap[oui] ?? '';
  }

  /// Determine if a device might be an HVAC tool based on OUI
  bool _isLikelyHvacTool(String macAddress) {
    final ouiMfr = _getMacOuiManufacturer(macAddress);
    // Texas Instruments chips are common in Fieldpiece, CPS, etc.
    return ouiMfr.contains('Texas Instruments') ||
        ouiMfr.contains('Fieldpiece') ||
        ouiMfr.contains('HVAC');
  }

  /// Check if device is a Fieldpiece broadcast-only device
  /// Fieldpiece manufacturer ID is 0x5046 (20550 decimal) = "PF"
  bool _isFieldpieceDevice(Map<int, List<int>> manufacturerData) {
    return manufacturerData.containsKey(0x5046);
  }

  /// Build a preview widget showing Fieldpiece measurement data from advertisement
  /// Fieldpiece devices broadcast measurement data directly - no GATT connection needed
  Widget _buildFieldpieceDataPreview(Map<int, List<int>> manufacturerData) {
    final data = manufacturerData[0x5046];
    if (data == null || data.length < 4) {
      return const SizedBox.shrink();
    }

    // Bytes 2-3 contain device type code
    final deviceTypeCode = String.fromCharCodes(data.sublist(2, 4));
    String deviceTypeName = getFieldpieceDeviceTypeName(data);
    String reading = 'N/A';
    
    // Extract battery and model info
    final batteryLevel = getFieldpieceBatteryLevel(data);
    final modelNumber = getFieldpieceModelNumber(data);
    String deviceInfo = deviceTypeName;
    if (modelNumber != null) {
      deviceInfo += ' ($modelNumber)';
    }

    // Identify device type and parse reading using device_registry parsers
    switch (deviceTypeCode) {
      case 'BF': // Temperature Clamp (Model 8975)
        final tempF = parseFieldpieceTemp(data);
        if (!tempF.isNaN) {
          reading = '${tempF.toStringAsFixed(1)}°F';
        }
        break;

      case 'BG': // Pressure Probe (Model 2975/2976)
        final psig = parseFieldpiecePressure(data);
        if (!psig.isNaN) {
          reading = '${psig.toStringAsFixed(1)} psig';
        }
        break;

      case 'BH': // Psychrometer (Model 5699)
        // Get full readings (wet bulb, dry bulb, humidity)
        final readings = parseFieldpiecePsychrometerFull(data);
        final wetBulb = readings['wetBulb'] ?? double.nan;
        final dryBulb = readings['dryBulb'] ?? double.nan;
        final humidity = readings['humidity'] ?? double.nan;
        
        List<String> readingParts = [];
        if (!wetBulb.isNaN) {
          readingParts.add('WB: ${wetBulb.toStringAsFixed(1)}°F');
        }
        if (!dryBulb.isNaN) {
          readingParts.add('DB: ${dryBulb.toStringAsFixed(1)}°F');
        }
        if (!humidity.isNaN) {
          readingParts.add('${humidity.toStringAsFixed(1)}%RH');
        }
        
        if (readingParts.isNotEmpty) {
          reading = readingParts.join(', ');
        }
        break;

      case 'CB': // SC680 Meter
        final value = parseFieldpieceSC680(data);
        if (!value.isNaN) {
          reading = '${value.toStringAsFixed(1)}A';
        }
        break;
    }

     return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primaryCyan.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sensors, size: 12, color: AppColors.primaryCyan),
          const SizedBox(width: 4),
          Text(
            'Fieldpiece $deviceInfo: $reading',
            style: const TextStyle(
              color: AppColors.primaryCyan,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (batteryLevel != null) ...[
            const SizedBox(width: 6),
            Icon(
              batteryLevel > 50 ? Icons.battery_full : 
              batteryLevel > 20 ? Icons.battery_std : Icons.battery_alert,
              size: 12,
              color: batteryLevel > 20 ? AppColors.primaryCyan : Colors.orange,
            ),
            const SizedBox(width: 2),
            Text(
              '$batteryLevel%',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Format manufacturer data as hex string for display
  String _formatManufacturerDataHex(Map<int, List<int>> data) {
    if (data.isEmpty) return '';
    final entry = data.entries.first;
    final companyId =
        '0x${entry.key.toRadixString(16).padLeft(4, '0').toUpperCase()}';
    final payload = entry.value
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
    final suffix = entry.value.length > 8 ? '...' : '';
    return '$companyId: $payload$suffix';
  }

  /// Format service data as hex string
  String _formatServiceData(Map<ble.Guid, List<int>> data) {
    if (data.isEmpty) return '';
    return data.entries.take(1).map((e) {
      final uuid = _shortenUuid(e.key.toString());
      final payload = e.value
          .take(8)
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
      final suffix = e.value.length > 8 ? '...' : '';
      return '$uuid: $payload$suffix';
    }).join(', ');
  }

  /// Guess device type from name and advertised services
  String _guessDeviceType(String name, List<ble.Guid> services) {
    final nameLower = name.toLowerCase();
    final serviceStrings =
        services.map((s) => s.toString().toLowerCase()).toList();

    // HVAC-specific tools
    if (nameLower.contains('testo') ||
        nameLower.contains('t115') ||
        nameLower.contains('t549') ||
        nameLower.contains('t605') ||
        nameLower.contains('t770') ||
        nameLower.contains('t870')) {
      if (nameLower.contains('pressure') ||
          nameLower.contains('549') ||
          nameLower.contains('550')) return 'Pressure Probe';
      if (nameLower.contains('temp') || nameLower.contains('115'))
        return 'Temp Probe';
      if (nameLower.contains('humid') || nameLower.contains('605'))
        return 'Humidity Probe';
      if (nameLower.contains('770') || nameLower.contains('thermal'))
        return 'Thermal Imager';
      return 'Testo Probe';
    }
    if (nameLower.contains('wey-tek') ||
        nameLower.contains('weytek') ||
        nameLower.contains('inficon')) {
      return 'Refrigerant Scale';
    }
    if (nameLower.contains('fieldpiece') ||
        nameLower.startsWith('jl3') ||
        nameLower.startsWith('sman') ||
        nameLower.startsWith('sdp') ||
        nameLower.startsWith('srs') ||
        nameLower.startsWith('srp') ||
        nameLower.startsWith('sdmn') ||
        nameLower.startsWith('job') ||
        nameLower.startsWith('fp')) {
      if (nameLower.contains('jl3')) return 'Vacuum Gauge';
      if (nameLower.contains('sman') || nameLower.contains('sdmn'))
        return 'Manifold';
      if (nameLower.contains('sdp')) return 'Pressure Probe';
      if (nameLower.contains('srp')) return 'Psychrometer';
      if (nameLower.contains('srs')) return 'Refrigerant Scale';
      if (nameLower.contains('job')) return 'Job Link';
      return 'Fieldpiece Tool';
    }
    // ABM-200 detection (CPS/AAB/WeatherFlow)
    if (nameLower.contains('abm') ||
        nameLower.contains('aab') ||
        nameLower.contains('weatherflow')) {
      return 'ABM-200 Airflow';
    }
    if (nameLower.contains('ccs') || nameLower.contains('airflow')) {
      return 'Airflow Meter';
    }
    if (nameLower.contains('navac')) {
      if (nameLower.contains('nr')) return 'Recovery Machine';
      if (nameLower.contains('nrc')) return 'Reclaim Unit';
      return 'Navac Tool';
    }
    if (nameLower.contains('yellow jacket') ||
        nameLower.contains('yj') ||
        nameLower.contains('p51')) {
      return 'YJ Gauge';
    }
    if (nameLower.contains('robinair')) {
      return 'Robinair Gauge';
    }
    if (nameLower.contains('mastercool')) {
      return 'Mastercool Tool';
    }
    if (nameLower.contains('supco')) {
      return 'Supco Tool';
    }
    if (nameLower.contains('uei') || nameLower.contains('test')) {
      return 'UEi Meter';
    }
    if (nameLower.contains('scale') && !nameLower.contains('gray')) {
      return 'Refrigerant Scale';
    }

    // Check for known HVAC service UUIDs
    for (final svc in serviceStrings) {
      if (svc.contains('961f0001'))
        return 'ABM-200 Airflow'; // ABM-200 specific
      if (svc.contains('fff0')) return 'Smart Probe'; // Testo uses this
      if (svc.contains('e3b744f3')) return 'Wey-Tek Scale'; // Wey-Tek UUID
      if (svc.contains('1809')) return 'Health Thermometer';
      if (svc.contains('180f')) return 'Battery Service';
      if (svc.contains('180a')) return 'Device Info';
    }

    // Generic device types
    if (nameLower.contains('heart') || nameLower.contains('hr'))
      return 'Heart Rate';
    if (nameLower.contains('watch')) return 'Watch';
    if (nameLower.contains('band')) return 'Fitness Band';
    if (nameLower.contains('earbuds') ||
        nameLower.contains('airpods') ||
        nameLower.contains('buds')) return 'Earbuds';
    if (nameLower.contains('speaker')) return 'Speaker';
    if (nameLower.contains('keyboard')) return 'Keyboard';
    if (nameLower.contains('mouse')) return 'Mouse';
    if (nameLower.contains('phone') ||
        nameLower.contains('iphone') ||
        nameLower.contains('pixel')) return 'Phone';
    if (nameLower.contains('tv')) return 'TV';
    if (nameLower.contains('thermostat')) return 'Thermostat';

    return 'unknown';
  }

  /// Get appropriate icon for device type
  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'temp probe':
      case 'pressure probe':
      case 'testo probe':
      case 'smart probe':
        return Icons.thermostat;
      case 'refrigerant scale':
      case 'wey-tek scale':
        return Icons.scale;
      case 'vacuum gauge':
      case 'manifold':
      case 'yj gauge':
        return Icons.speed;
      case 'airflow meter':
        return Icons.air;
      case 'fieldpiece tool':
      case 'recovery machine':
        return Icons.build;
      case 'heart rate':
      case 'fitness band':
        return Icons.favorite;
      case 'watch':
        return Icons.watch;
      case 'earbuds':
        return Icons.headphones;
      case 'speaker':
        return Icons.speaker;
      case 'keyboard':
        return Icons.keyboard;
      case 'mouse':
        return Icons.mouse;
      case 'phone':
        return Icons.phone_android;
      case 'tv':
        return Icons.tv;
      case 'thermostat':
        return Icons.device_thermostat;
      case 'health thermometer':
        return Icons.medical_services;
      default:
        return Icons.bluetooth;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'BLE Sniffer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Settings icon
          IconButton(
            icon: const Icon(
              Icons.settings,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BleSnifferSettingsScreen(),
                ),
              ).then((_) {
                // Reload settings after returning from settings screen
                _uploadService.loadSettings();
              });
            },
            tooltip: 'BLE Sniffer Settings',
          ),
          // History toggle
          IconButton(
            icon: Icon(
              Icons.history,
              color: _showHistory
                  ? AppColors.primaryCyan
                  : AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _showHistory = !_showHistory),
            tooltip: 'Session History',
          ),
          // Data interpreter toggle
          IconButton(
            icon: Icon(
              Icons.analytics,
              color: _showDataInterpreter
                  ? AppColors.primaryCyan
                  : AppColors.textSecondary,
            ),
            onPressed: _toggleDataInterpreter,
            tooltip: 'Toggle Data Interpreter',
          ),
          // Save Profile button
          if (_connectedDevice != null)
            IconButton(
              icon: const Icon(Icons.save, color: AppColors.success),
              onPressed: _generateProfile,
              tooltip: 'Save Profile',
            ),
          if (_connectedDevice != null)
            IconButton(
              icon: const Icon(Icons.link_off, color: AppColors.error),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            ),
          // More options popup
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            color: AppColors.surfaceDark,
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _clearLogs();
                  break;
                case 'export':
                  _exportLogs();
                  break;
                case 'share':
                  _shareLogs();
                  break;
                case 'sync':
                  _syncToFirebase();
                  break;
                case 'history':
                  setState(() => _showHistory = !_showHistory);
                  break;
                case 'interpreter':
                  _toggleDataInterpreter();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'interpreter',
                child: Row(
                  children: [
                    Icon(
                      Icons.analytics,
                      color: _showDataInterpreter
                          ? AppColors.primaryCyan
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _showDataInterpreter
                          ? 'Hide Interpretations'
                          : 'Show Interpretations',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.copy, color: AppColors.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Text('Copy to Clipboard',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, color: AppColors.primaryCyan, size: 20),
                    SizedBox(width: 12),
                    Text('Share Logs', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload,
                        color: AppColors.success, size: 20),
                    SizedBox(width: 12),
                    Text('Sync to Cloud',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history,
                        color: _showHistory
                            ? AppColors.primaryCyan
                            : AppColors.textSecondary,
                        size: 20),
                    const SizedBox(width: 12),
                    Text('Session History (${_savedSessions.length})',
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        color: AppColors.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Text('Clear Logs', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            // History panel (collapsible)
            if (_showHistory) _buildHistoryPanel(),
            // Connection status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _connectedDevice != null
                  ? AppColors.success.withOpacity(0.2)
                  : AppColors.surfaceDark,
              child: Row(
                children: [
                  Icon(
                    _connectedDevice != null
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth,
                    color: _connectedDevice != null
                        ? AppColors.success
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _connectedDevice != null
                              ? 'Connected: ${_getDisplayName()}'
                              : 'Not connected',
                          style: TextStyle(
                            color: _connectedDevice != null
                                ? AppColors.success
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Show real name from Device Info Service if available
                        if (_connectedDevice != null &&
                            (_deviceManufacturer != null ||
                                _deviceModelNumber != null))
                          Text(
                            '${_deviceManufacturer ?? ""} ${_deviceModelNumber ?? ""}'
                                .trim(),
                            style: const TextStyle(
                              color: AppColors.primaryCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        // Show serial and firmware if available
                        if (_connectedDevice != null &&
                            (_deviceSerialNumber != null ||
                                _deviceFirmwareRev != null ||
                                _deviceHardwareRev != null))
                          Text(
                            [
                              if (_deviceSerialNumber != null)
                                'S/N: $_deviceSerialNumber',
                              if (_deviceFirmwareRev != null)
                                'FW: $_deviceFirmwareRev',
                              if (_deviceHardwareRev != null)
                                'HW: $_deviceHardwareRev',
                            ].join(' | '),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 9,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_connectedDevice == null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Apple filter toggle
                        Tooltip(
                          message: _hideAppleDevices
                              ? 'Show Apple devices'
                              : 'Hide Apple devices',
                          child: IconButton(
                            onPressed: () => setState(
                                () => _hideAppleDevices = !_hideAppleDevices),
                            icon: Icon(
                              Icons.apple,
                              color: _hideAppleDevices
                                  ? AppColors.textMuted
                                  : AppColors.primaryCyan,
                              size: 20,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: _hideAppleDevices
                                  ? Colors.transparent
                                  : AppColors.primaryCyan.withOpacity(0.2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isScanning ? _stopScan : _startScan,
                          icon: Icon(
                            _isScanning ? Icons.stop : Icons.search,
                            size: 18,
                          ),
                          label: Text(_isScanning ? 'Stop' : 'Scan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isScanning
                                ? AppColors.error
                                : AppColors.primaryCyan,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: _connectedDevice == null
                  ? _buildScanResults()
                  : _buildServiceExplorer(),
            ),

            // Log panel
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.terminal,
                            color: AppColors.primaryCyan, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Console',
                          style: TextStyle(
                            color: AppColors.primaryCyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_logEntries.length} entries',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _logScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _logEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _logEntries[index];
                        return _buildLogEntry(entry,
                            key: ValueKey('log_$index'));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.history,
                    color: AppColors.primaryCyan, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Saved Sessions (${_savedSessions.length})',
                  style: const TextStyle(
                    color: AppColors.primaryCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.textSecondary, size: 18),
                  onPressed: () => setState(() => _showHistory = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _savedSessions.isEmpty
                ? const Center(
                    child: Text(
                      'No saved sessions yet.\nSessions auto-save after scans.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _savedSessions.length,
                    itemBuilder: (context, index) {
                      final session = _savedSessions[index];
                      final date = DateTime.tryParse(session['date'] ?? '') ??
                          DateTime.now();
                      final deviceCount = session['deviceCount'] ?? 0;
                      final logCount = session['logCount'] ?? 0;
                      final connectedDevice = session['connectedDevice'];

                      return Card(
                        key: ValueKey(session['sessionId'] ?? 'session_$index'),
                        color: AppColors.surfaceLight,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            connectedDevice != null
                                ? Icons.bluetooth_connected
                                : Icons.bluetooth_searching,
                            color: connectedDevice != null
                                ? AppColors.success
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          title: Text(
                            connectedDevice != null
                                ? connectedDevice['name'] ?? 'Unknown'
                                : '$deviceCount devices scanned',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')} • $logCount logs',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.cloud_upload,
                                    color: AppColors.primaryCyan, size: 18),
                                onPressed: () =>
                                    _syncSessionToFirebase(session),
                                tooltip: 'Sync to Cloud',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.error, size: 18),
                                onPressed: () => _deleteSession(session['id']),
                                tooltip: 'Delete',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          onTap: () => _loadSession(session),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _loadSession(Map<String, dynamic> session) {
    setState(() {
      _logEntries.clear();
      final logs = session['logs'] as List? ?? [];
      for (final log in logs) {
        _logEntries.add(_LogEntry(
          timestamp: DateTime.tryParse(log['time'] ?? '') ?? DateTime.now(),
          message: log['msg'] ?? '',
          type: log['type'] ?? 'info',
        ));
      }
      _showHistory = false;
    });
    _addLog('Loaded session from ${session['date']}', type: 'info');
  }

  Future<void> _deleteSession(String? sessionId) async {
    if (sessionId == null || _sniffBox == null) return;
    await _sniffBox!.delete(sessionId);
    _loadSavedSessions();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session deleted'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _syncSessionToFirebase(Map<String, dynamic> session) async {
    try {
      final docId =
          'sniff_${session['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance
          .collection('ble_sniff_logs')
          .doc(docId)
          .set({
        ...session,
        'syncedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session synced to cloud'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildScanResults() {
    if (_isConnecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryCyan),
            SizedBox(height: 16),
            Text('Connecting...',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_scanResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              _isScanning
                  ? 'Scanning for devices...'
                  : 'Tap Scan to find devices',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Filter out Apple devices if toggle is enabled
    final filteredResults = _hideAppleDevices
        ? _scanResults.where((result) {
            final adv = result.advertisementData;
            // Apple's Bluetooth Company ID is 0x004C (76)
            final isApple = adv.manufacturerData.containsKey(0x004C) ||
                result.device.platformName.toLowerCase().contains('apple') ||
                result.device.platformName.toLowerCase().contains('iphone') ||
                result.device.platformName.toLowerCase().contains('ipad') ||
                result.device.platformName.toLowerCase().contains('airpod') ||
                result.device.platformName.toLowerCase().contains('macbook') ||
                result.device.platformName.toLowerCase().contains('watch');
            return !isApple;
          }).toList()
        : _scanResults;

    if (filteredResults.isEmpty && _scanResults.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_alt_off,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              '${_scanResults.length} devices hidden (Apple filter)',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _hideAppleDevices = false),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Show Apple Devices'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final result = filteredResults[index];
        final device = result.device;
        final rssi = result.rssi;
        final adv = result.advertisementData;

        // Get best available name
        final name = device.platformName.isNotEmpty
            ? device.platformName
            : (adv.advName.isNotEmpty ? adv.advName : 'Unknown Device');

        // Extract manufacturer info from advertising data OR MAC OUI
        String manufacturerInfo = _getManufacturerName(adv.manufacturerData);
        final macOui = _getMacOuiManufacturer(device.remoteId.str);
        final isLikelyHvac = _isLikelyHvacTool(device.remoteId.str);

        // If no manufacturer data but we have OUI info, show that
        if (manufacturerInfo.isEmpty && macOui.isNotEmpty) {
          manufacturerInfo = 'Chip: $macOui';
        }

        // Get advertised service UUIDs (first 2 for display)
        final services = adv.serviceUuids
            .take(2)
            .map((u) => _shortenUuid(u.toString()))
            .join(', ');

        // Guess device type from name/services
        final deviceType = _guessDeviceType(name, adv.serviceUuids);

        return Card(
          key: ValueKey(device.remoteId.str),
          color: isLikelyHvac
              ? AppColors.surfaceDark.withOpacity(0.9)
              : AppColors.surfaceDark,
          margin: const EdgeInsets.only(bottom: 8),
          shape: isLikelyHvac
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.warning, width: 1),
                )
              : null,
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getDeviceIcon(deviceType),
                  color: rssi > -60
                      ? AppColors.success
                      : (rssi > -80 ? AppColors.warning : AppColors.error),
                ),
                const SizedBox(height: 2),
                Text(
                  '$rssi',
                  style: TextStyle(
                    color: rssi > -60
                        ? AppColors.success
                        : (rssi > -80 ? AppColors.warning : AppColors.error),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            title: Text(
              name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // MAC address
                Text(
                  device.remoteId.str,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace'),
                ),
                // Local name if different from platform name
                if (adv.advName.isNotEmpty &&
                    adv.advName != device.platformName)
                  Text(
                    'Local Name: ${adv.advName}',
                    style:
                        const TextStyle(color: AppColors.warning, fontSize: 10),
                  ),
                // Manufacturer if known
                if (manufacturerInfo.isNotEmpty)
                  Text(
                    manufacturerInfo,
                    style: const TextStyle(
                        color: AppColors.primaryCyan, fontSize: 10),
                  ),
                // Raw manufacturer data (for debugging unknown devices)
                if (adv.manufacturerData.isNotEmpty)
                  Text(
                    'Mfr Data: ${_formatManufacturerDataHex(adv.manufacturerData)}',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        fontFamily: 'monospace'),
                  ),
                // Device type guess
                if (deviceType != 'unknown')
                  Text(
                    'Type: $deviceType',
                    style:
                        const TextStyle(color: AppColors.success, fontSize: 10),
                  ),
                // Service UUIDs
                if (services.isNotEmpty)
                  Text(
                    'Services: $services',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 9),
                  ),
                // Service data (often contains model/serial info)
                if (adv.serviceData.isNotEmpty)
                  Text(
                    'Svc Data: ${_formatServiceData(adv.serviceData)}',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        fontFamily: 'monospace'),
                  ),
                // TX power if available
                if (adv.txPowerLevel != null)
                  Text(
                    'TX Power: ${adv.txPowerLevel} dBm',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 9),
                  ),
                // Connectable status
                Text(
                  adv.connectable ? 'Connectable' : 'Not Connectable',
                  style: TextStyle(
                    color: adv.connectable
                        ? AppColors.success
                        : AppColors.textMuted,
                    fontSize: 9,
                  ),
                ),
                // Fieldpiece broadcast-only warning
                if (_isFieldpieceDevice(adv.manufacturerData))
                  Text(
                    '⚠️ Broadcast-only (reads from advertisement)',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                // Show Fieldpiece measurement data if available
                if (_isFieldpieceDevice(adv.manufacturerData))
                  _buildFieldpieceDataPreview(adv.manufacturerData),
              ],
            ),
            trailing: adv.connectable
                ? IconButton(
                    icon: const Icon(Icons.arrow_forward_ios,
                        color: AppColors.primaryCyan, size: 18),
                    onPressed: () => _connectToDevice(device),
                  )
                : const Icon(Icons.broadcast_on_personal,
                    color: AppColors.textMuted, size: 18),
            onTap: adv.connectable ? () => _connectToDevice(device) : null,
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildServiceExplorer() {
    if (_services.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryCyan),
            SizedBox(height: 16),
            Text('Discovering services...',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        return _buildServiceCard(service,
            key: ValueKey(service.uuid.toString()));
      },
    );
  }

  Widget _buildServiceCard(ble.BluetoothService service, {Key? key}) {
    return Card(
      key: key,
      color: AppColors.surfaceDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(Icons.folder, color: AppColors.primaryCyan),
        title: GestureDetector(
          onLongPress: () => _copyToClipboard(service.uuid.toString()),
          child: Text(
            service.uuid.toString(),
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        subtitle: Text(
          '${service.characteristics.length} characteristics',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textSecondary,
        children: service.characteristics
            .map((char) => _buildCharacteristicTile(char))
            .toList(),
      ),
    );
  }

  Widget _buildCharacteristicTile(ble.BluetoothCharacteristic char) {
    final props = <String>[];
    if (char.properties.read) props.add('Read');
    if (char.properties.write) props.add('Write');
    if (char.properties.writeWithoutResponse) props.add('WriteNoResp');
    if (char.properties.notify) props.add('Notify');
    if (char.properties.indicate) props.add('Indicate');

    final isSubscribed = _notifySubscriptions.containsKey(char.uuid.toString());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: AppColors.border.withOpacity(0.3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _copyToClipboard(char.uuid.toString()),
            child: Text(
              char.uuid.toString(),
              style: const TextStyle(
                  color: AppColors.primaryCyan,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: props
                .map((p) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(p,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 9)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (char.properties.read)
                _buildActionButton(
                  icon: Icons.download,
                  label: 'Read',
                  onTap: () => _readCharacteristic(char),
                ),
              if (char.properties.notify || char.properties.indicate)
                _buildActionButton(
                  icon: isSubscribed
                      ? Icons.notifications_off
                      : Icons.notifications,
                  label: isSubscribed ? 'Unsub' : 'Subscribe',
                  isActive: isSubscribed,
                  onTap: () => _toggleNotify(char),
                ),
              if (char.properties.write || char.properties.writeWithoutResponse)
                _buildActionButton(
                  icon: Icons.upload,
                  label: 'Write',
                  onTap: () => _writeToCharacteristic(char),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.success.withOpacity(0.2)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? AppColors.success : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color:
                      isActive ? AppColors.success : AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.success : AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogEntry(_LogEntry entry, {Key? key}) {
    Color color;
    switch (entry.type) {
      case 'error':
        color = AppColors.error;
        break;
      case 'success':
        color = AppColors.success;
        break;
      case 'warning':
        color = AppColors.warning;
        break;
      case 'action':
        color = AppColors.primaryCyan;
        break;
      case 'notify':
        color = const Color(0xFFFFD700);
        break;
      case 'data':
        color = const Color(0xFF888888);
        break;
      case 'debug':
        color = const Color(0xFF66AAFF); // Light blue for debug interpretations
        break;
      default:
        color = AppColors.textSecondary;
    }

    final time = '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        onLongPress: () => _copyToClipboard(entry.message),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            children: [
              TextSpan(
                text: '[$time] ',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              TextSpan(
                text: entry.message,
                style: TextStyle(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogEntry {
  final DateTime timestamp;
  final String message;
  final String type;

  _LogEntry({
    required this.timestamp,
    required this.message,
    required this.type,
  });
}
