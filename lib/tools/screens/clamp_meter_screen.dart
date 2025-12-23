import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../bluetooth/bluetooth_service.dart';
import '../services/device_data_service.dart';
import '../services/device_registry.dart';
import '../services/auto_reconnect_service.dart';
import '../services/device_storage_service.dart';

/// Clamp Meter screen - displays Fieldpiece SC680 and similar clamp meter readings
/// Supports: AC/DC Voltage, AC/DC Current, Resistance, Capacitance, Frequency
class ClampMeterScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const ClampMeterScreen({super.key, required this.onToggleTheme});

  @override
  State<ClampMeterScreen> createState() => _ClampMeterScreenState();
}

class _ClampMeterScreenState extends State<ClampMeterScreen> {
  final BluetoothService _bleService = BluetoothService();
  final DeviceDataService _dataService = DeviceDataService();
  final AutoReconnectService _reconnectService = AutoReconnectService();
  final DeviceStorageService _storageService = DeviceStorageService();
  final DeviceRegistry _registry = DeviceRegistry();

  // Current readings
  double _currentValue = 0.0;
  String _currentUnit = 'A';
  String _measurementType = 'AC Current';
  
  String? _connectedDeviceId;
  String? _connectedDeviceName;
  bool _isConnected = false;
  bool _isScanning = false;
  int? _batteryLevel;

  StreamSubscription? _deviceUpdatesSubscription;
  StreamSubscription? _disconnectSubscription;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _batterySubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _bleService.init();
    await _dataService.init();
    await _storageService.init();
    await _reconnectService.init();
    _listenForDeviceUpdates();
    _listenForBatteryUpdates();
    await _checkForConnectedMeters();
  }

  void _listenForBatteryUpdates() {
    _batterySubscription = _dataService.batteryUpdates.listen((battery) {
      if (!mounted) return;
      if (_connectedDeviceId != null &&
          battery.deviceId == _connectedDeviceId) {
        setState(() {
          _batteryLevel = battery.level;
        });
      }
    });
  }

  Future<void> _checkForConnectedMeters() async {
    final devices = await _storageService.getSavedDevices();
    for (final d in devices) {
      final profile = _registry.identifyByName(d.name);
      if (profile?.type == HvacDeviceType.clampMeter) {
        setState(() {
          _connectedDeviceId = d.remoteId;
          _connectedDeviceName = d.name;
          _isConnected = true;
        });
        return;
      }
    }

    // No meter found - auto-scan
    await _autoScanForMeters();
  }

  Future<void> _autoScanForMeters() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
    });

    try {
      await _bleService.startScan(timeout: const Duration(seconds: 10));

      _scanSubscription = _bleService.scanResults.listen((results) async {
        for (final result in results) {
          final deviceName = result.device.platformName;
          if (deviceName.isEmpty) continue;

          // Check for Fieldpiece clamp meters (SC680, etc.)
          final profile = _registry.identifyByName(deviceName);
          if (profile?.type == HvacDeviceType.clampMeter) {
            await _bleService.stopScan();
            _scanSubscription?.cancel();

            if (!mounted) return;

            // Fieldpiece devices are broadcast-only, no connection needed
            // Just save them and listen for broadcasts
            final now = DateTime.now();
            await _storageService.saveDevice(SavedDevice(
              remoteId: result.device.remoteId.str,
              name: deviceName,
              manufacturer: profile!.manufacturer.toString().split('.').last,
              deviceType: profile.type.toString().split('.').last,
              unit: profile.unit,
              firstPaired: now,
              lastSeen: now,
              autoReconnect: true,
            ));

            setState(() {
              _connectedDeviceId = result.device.remoteId.str;
              _connectedDeviceName = deviceName;
              _isConnected = true;
              _isScanning = false;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.bluetooth_connected,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Text('Receiving broadcasts from $deviceName'),
                    ],
                  ),
                  backgroundColor: AppColors.success.withOpacity(0.9),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              );
            }
            return;
          }
        }
      });

      await Future.delayed(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[ClampMeter] Scan error: $e');
    } finally {
      _scanSubscription?.cancel();
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _listenForDeviceUpdates() {
    // Listen for disconnect events
    _disconnectSubscription =
        _reconnectService.reconnectStatus.listen((status) {
      if (!mounted) return;

      if (status.state == ReconnectState.disconnected &&
          status.deviceId == _connectedDeviceId) {
        final deviceName = _connectedDeviceName ?? 'Clamp Meter';
        setState(() {
          _isConnected = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bluetooth_disabled,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('$deviceName disconnected')),
              ],
            ),
            backgroundColor: AppColors.error.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } else if (status.state == ReconnectState.connected &&
          status.deviceId == _connectedDeviceId) {
        setState(() {
          _isConnected = true;
        });

        final deviceName = _connectedDeviceName ?? 'Clamp Meter';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bluetooth_connected,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('$deviceName connected')),
              ],
            ),
            backgroundColor: AppColors.success.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    });

    // Listen for real-time readings from clamp meters
    _deviceUpdatesSubscription = _dataService.readings.listen((reading) {
      if (!mounted) return;

      // Only process clamp meter readings
      if (reading.type == HvacDeviceType.clampMeter) {
        setState(() {
          _currentValue = reading.value;
          _currentUnit = reading.unit;
          _connectedDeviceId = reading.deviceId;
          _connectedDeviceName = reading.deviceName;
          _isConnected = true;
          
          // Determine measurement type from unit
          if (reading.unit == 'V' || reading.unit == 'mV') {
            _measurementType = 'Voltage';
          } else if (reading.unit == 'A' || reading.unit == 'mA') {
            _measurementType = 'Current';
          } else if (reading.unit == 'Ω' || reading.unit == 'kΩ' || reading.unit == 'MΩ') {
            _measurementType = 'Resistance';
          } else if (reading.unit == 'Hz') {
            _measurementType = 'Frequency';
          } else if (reading.unit == 'µF' || reading.unit == 'nF') {
            _measurementType = 'Capacitance';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _deviceUpdatesSubscription?.cancel();
    _disconnectSubscription?.cancel();
    _scanSubscription?.cancel();
    _batterySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Clamp Meter'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isScanning
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primaryCyan),
                    ),
                  )
                : Icon(
                    _isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_searching,
                    color:
                        _isConnected ? AppColors.success : AppColors.textMuted,
                  ),
            onPressed: _isScanning
                ? null
                : () {
                    if (_isConnected) {
                      Navigator.pushNamed(context, '/devices');
                    } else {
                      _autoScanForMeters();
                    }
                  },
            tooltip: _isScanning
                ? 'Scanning...'
                : (_isConnected ? 'Device Manager' : 'Scan for Meters'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Connection/scanning status
              if (!_isConnected)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _isScanning
                        ? AppColors.primaryCyan.withOpacity(0.2)
                        : AppColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _isScanning
                            ? AppColors.primaryCyan
                            : AppColors.warning),
                  ),
                  child: Row(
                    children: [
                      if (_isScanning) ...[
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryCyan),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Scanning for Fieldpiece clamp meters...',
                            style: TextStyle(color: AppColors.primaryCyan),
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.info_outline, color: AppColors.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No clamp meter detected. Make sure your Fieldpiece meter is on and nearby.',
                            style: TextStyle(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Main reading display
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Measurement type label
                      Text(
                        _measurementType,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Large value display
                      Text(
                        _currentValue.toStringAsFixed(
                          _currentUnit == 'A' || _currentUnit == 'V' ? 2 : 0
                        ),
                        style: TextStyle(
                          fontSize: 96,
                          fontWeight: FontWeight.bold,
                          color: _isConnected 
                              ? AppColors.textPrimary 
                              : AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        _currentUnit,
                        style: TextStyle(
                          fontSize: 32,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Device info
                      if (_connectedDeviceName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt,
                                color: AppColors.warning,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _connectedDeviceName!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_batteryLevel != null) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  _batteryLevel! > 50
                                      ? Icons.battery_full
                                      : _batteryLevel! > 20
                                          ? Icons.battery_4_bar
                                          : Icons.battery_1_bar,
                                  size: 18,
                                  color: _batteryLevel! > 50
                                      ? AppColors.success
                                      : _batteryLevel! > 20
                                          ? AppColors.warning
                                          : AppColors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$_batteryLevel%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Info card about Fieldpiece broadcast mode
              if (!_isConnected && !_isScanning)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.info.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fieldpiece clamp meters broadcast readings. Tap the bluetooth icon to scan.',
                          style: TextStyle(
                            color: AppColors.info,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
