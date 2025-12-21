import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../bluetooth/bluetooth_service.dart';
import '../services/device_data_service.dart';
import '../services/device_registry.dart';
import '../services/auto_reconnect_service.dart';
import '../services/device_storage_service.dart';
import '../services/scale_settings.dart';

/// Scale screen - displays refrigerant scale weight readings
class ScaleScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const ScaleScreen({super.key, required this.onToggleTheme});

  @override
  State<ScaleScreen> createState() => _ScaleScreenState();
}

class _ScaleScreenState extends State<ScaleScreen> {
  final BluetoothService _bleService = BluetoothService();
  final DeviceDataService _dataService = DeviceDataService();
  final AutoReconnectService _reconnectService = AutoReconnectService();
  final DeviceStorageService _storageService = DeviceStorageService();
  final DeviceRegistry _registry = DeviceRegistry();
  final ScaleSettings _scaleSettings = ScaleSettings.instance;

  // Current weight reading
  double _currentWeight = 0.0;
  String? _connectedDeviceId;
  String? _connectedDeviceName;
  bool _isConnected = false;

  // Target weight for charging
  double? _targetWeight;
  double _startWeight = 0.0;
  double _chargedAmount = 0.0;

  // Auto-scan state
  bool _isScanning = false;

  // Battery level
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
    await _scaleSettings.init();
    _listenForDeviceUpdates();
    _listenForBatteryUpdates();
    await _checkForConnectedScales();
  }

  void _listenForBatteryUpdates() {
    _batterySubscription = _dataService.batteryUpdates.listen((battery) {
      if (!mounted) return;
      // Update battery if it's from our connected scale
      if (_connectedDeviceId != null &&
          battery.deviceId == _connectedDeviceId) {
        setState(() {
          _batteryLevel = battery.level;
        });
      }
    });
  }

  Future<void> _checkForConnectedScales() async {
    final devices = await _storageService.getSavedDevices();
    for (final d in devices) {
      final profile = _registry.identifyByName(d.name);
      if (profile?.type == HvacDeviceType.refrigerantScale) {
        setState(() {
          _connectedDeviceId = d.remoteId;
          _connectedDeviceName = d.name;
          _isConnected = true;
        });
        return; // Found a connected scale, no need to scan
      }
    }

    // No scale found - auto-scan for compatible scales
    await _autoScanForScales();
  }

  Future<void> _autoScanForScales() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
    });

    try {
      // Start BLE scan
      await _bleService.startScan(timeout: const Duration(seconds: 10));

      // Listen for scan results
      _scanSubscription = _bleService.scanResults.listen((results) async {
        for (final result in results) {
          final deviceName = result.device.platformName;
          if (deviceName.isEmpty) continue;

          // Check if this is a refrigerant scale
          final profile = _registry.identifyByName(deviceName);
          if (profile?.type == HvacDeviceType.refrigerantScale) {
            // Found a scale - stop scanning and connect
            await _bleService.stopScan();
            _scanSubscription?.cancel();

            if (!mounted) return;

            // Auto-connect to the scale
            try {
              await _bleService.connectToDevice(result.device);
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
                serviceUuid: profile.serviceUuids.isNotEmpty
                    ? profile.serviceUuids.first
                    : null,
                characteristicUuid: profile.dataCharacteristicUuid,
              ));

              setState(() {
                _connectedDeviceId = result.device.remoteId.str;
                _connectedDeviceName = deviceName;
                _isConnected = true;
                _isScanning = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.bluetooth_connected,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Text('Found and connected to $deviceName'),
                    ],
                  ),
                  backgroundColor: AppColors.success.withOpacity(0.9),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              );
            } catch (e) {
              // Connection failed, but we found a scale
              if (mounted) {
                setState(() {
                  _isScanning = false;
                });
              }
            }
            return;
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));
    } catch (e) {
      // Scan failed
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
        final deviceName = _connectedDeviceName ?? 'Scale';
        setState(() {
          _isConnected = false;
        });

        // Show disconnect notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bluetooth_disabled,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$deviceName disconnected',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
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

        // Show reconnect notification
        final deviceName = _connectedDeviceName ?? 'Scale';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bluetooth_connected,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$deviceName connected',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
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

    // Listen for real-time readings from connected devices
    _deviceUpdatesSubscription = _dataService.readings.listen((reading) {
      if (!mounted) return;

      // Only process scale readings
      if (reading.type == HvacDeviceType.refrigerantScale) {
        setState(() {
          _currentWeight = reading.value;
          _connectedDeviceId = reading.deviceId;
          _connectedDeviceName = reading.deviceName;
          _isConnected = true;

          // Update charged amount if we have a start weight
          if (_targetWeight != null) {
            _chargedAmount = _currentWeight - _startWeight;
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

  void _setTargetWeight() {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        final unitLabel = _scaleSettings.unitSuffix;
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Text('Set Target Charge',
              style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter target weight ($unitLabel)',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.textMuted),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primaryCyan),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                final value = double.tryParse(controller.text);
                if (value != null) {
                  // Convert input to oz if needed for internal storage
                  double targetOz = value;
                  if (_scaleSettings.unit == ScaleUnit.kg) {
                    targetOz = value / 0.0283495; // kg to oz
                  }
                  setState(() {
                    _targetWeight = targetOz;
                    _startWeight = _currentWeight;
                    _chargedAmount = 0.0;
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Set',
                  style: TextStyle(color: AppColors.primaryCyan)),
            ),
          ],
        );
      },
    );
  }

  void _clearTarget() {
    setState(() {
      _targetWeight = null;
      _startWeight = 0.0;
      _chargedAmount = 0.0;
    });
  }

  Future<void> _tare() async {
    if (_connectedDeviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No scale connected'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final success = await _dataService.sendScaleTare(_connectedDeviceId!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Scale zeroed' : 'Failed to zero scale'),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showScaleSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ScaleSettingsSheet(
        currentUnit: _scaleSettings.unit,
        onUnitChanged: (unit) async {
          await _scaleSettings.setUnit(unit);
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Refrigerant Scale'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textSecondary),
            onPressed: _showScaleSettings,
            tooltip: 'Scale Settings',
          ),
          IconButton(
            icon: _isScanning
                ? const SizedBox(
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
                      _autoScanForScales();
                    }
                  },
            tooltip: _isScanning
                ? 'Scanning...'
                : (_isConnected ? 'Device Manager' : 'Scan for Scales'),
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
                        const SizedBox(
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
                            'Scanning for Wey-Tek scales...',
                            style: TextStyle(color: AppColors.primaryCyan),
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.warning, color: AppColors.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No scale connected. Tap bluetooth icon to scan.',
                            style: TextStyle(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Main weight display
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Weight value - formatted based on user's unit preference
                      if (_scaleSettings.unit == ScaleUnit.lbOz) ...[
                        Text(
                          _scaleSettings.formatWeight(_currentWeight),
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ] else ...[
                        Text(
                          _scaleSettings
                              .convertValue(_currentWeight)
                              .toStringAsFixed(
                                _scaleSettings.unit == ScaleUnit.kg ? 3 : 1,
                              ),
                          style: const TextStyle(
                            fontSize: 96,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          _scaleSettings.unitSuffix,
                          style: const TextStyle(
                            fontSize: 32,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Connected device name with battery
                      if (_connectedDeviceName != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _connectedDeviceName!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                            if (_batteryLevel != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                _batteryLevel! > 50
                                    ? Icons.battery_full
                                    : _batteryLevel! > 20
                                        ? Icons.battery_4_bar
                                        : Icons.battery_1_bar,
                                size: 16,
                                color: _batteryLevel! > 50
                                    ? AppColors.success
                                    : _batteryLevel! > 20
                                        ? AppColors.warning
                                        : AppColors.error,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$_batteryLevel%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _batteryLevel! > 50
                                      ? AppColors.success
                                      : _batteryLevel! > 20
                                          ? AppColors.warning
                                          : AppColors.error,
                                ),
                              ),
                            ],
                          ],
                        ),

                      const SizedBox(height: 48),

                      // Target charging section
                      if (_targetWeight != null) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _chargedAmount >= _targetWeight!
                                  ? AppColors.success
                                  : AppColors.primaryCyan,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'CHARGING',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMuted,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        _scaleSettings.unit == ScaleUnit.lbOz
                                            ? _scaleSettings
                                                .formatWeight(_chargedAmount)
                                            : _scaleSettings
                                                .convertValue(_chargedAmount)
                                                .toStringAsFixed(
                                                  _scaleSettings.unit ==
                                                          ScaleUnit.kg
                                                      ? 3
                                                      : 1,
                                                ),
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              _chargedAmount >= _targetWeight!
                                                  ? AppColors.success
                                                  : AppColors.primaryCyan,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      Text(
                                        'added${_scaleSettings.unit != ScaleUnit.lbOz ? ' ${_scaleSettings.unitSuffix}' : ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 24),
                                  const Text(
                                    '/',
                                    style: TextStyle(
                                      fontSize: 36,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Column(
                                    children: [
                                      Text(
                                        _scaleSettings.unit == ScaleUnit.lbOz
                                            ? _scaleSettings
                                                .formatWeight(_targetWeight!)
                                            : _scaleSettings
                                                .convertValue(_targetWeight!)
                                                .toStringAsFixed(
                                                  _scaleSettings.unit ==
                                                          ScaleUnit.kg
                                                      ? 3
                                                      : 1,
                                                ),
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textSecondary,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const Text(
                                        'target',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Progress bar
                              LinearProgressIndicator(
                                value: (_chargedAmount / _targetWeight!)
                                    .clamp(0.0, 1.0),
                                backgroundColor:
                                    AppColors.textMuted.withOpacity(0.3),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _chargedAmount >= _targetWeight!
                                      ? AppColors.success
                                      : AppColors.primaryCyan,
                                ),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              if (_chargedAmount >= _targetWeight!)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.check_circle,
                                          color: AppColors.success, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Target reached!',
                                        style: TextStyle(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _clearTarget,
                          child: const Text(
                            'Clear Target',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _tare,
                      icon: const Icon(Icons.exposure_zero),
                      label: const Text('TARE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceDark,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _setTargetWeight,
                      icon: const Icon(Icons.track_changes),
                      label: const Text('SET TARGET'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for scale settings
class _ScaleSettingsSheet extends StatelessWidget {
  final ScaleUnit currentUnit;
  final Function(ScaleUnit) onUnitChanged;

  const _ScaleSettingsSheet({
    required this.currentUnit,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: AppColors.primaryCyan, size: 24),
              const SizedBox(width: 12),
              Text(
                'Scale Settings',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Display Unit',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ScaleUnit.values.map((unit) {
              final isSelected = currentUnit == unit;
              return GestureDetector(
                onTap: () {
                  onUnitChanged(unit);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryCyan.withOpacity(0.2)
                        : AppColors.surfaceLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryCyan
                          : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    ScaleSettings.getUnitLabel(unit),
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primaryCyan
                          : AppColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
