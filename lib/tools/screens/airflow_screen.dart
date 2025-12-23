import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../bluetooth/bluetooth_service.dart';
import '../services/device_data_service.dart';
import '../services/device_registry.dart';
import '../services/auto_reconnect_service.dart';
import '../services/device_storage_service.dart';
import '../services/calibration_service.dart';
import '../widgets/calibration_popup.dart';

/// Airflow screen - displays ABM-200 airflow meter readings
/// Supports: Velocity (FPM), Temperature (°F), Humidity (%RH), Pressure
class AirflowScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const AirflowScreen({super.key, required this.onToggleTheme});

  @override
  State<AirflowScreen> createState() => _AirflowScreenState();
}

class _AirflowScreenState extends State<AirflowScreen> {
  final BluetoothService _bleService = BluetoothService();
  final DeviceDataService _dataService = DeviceDataService();
  final AutoReconnectService _reconnectService = AutoReconnectService();
  final DeviceStorageService _storageService = DeviceStorageService();
  final DeviceRegistry _registry = DeviceRegistry();
  final CalibrationService _calibrationService = CalibrationService();

  // Global keys for calibration popup positioning
  final GlobalKey _velocityKey = GlobalKey();
  final GlobalKey _tempKey = GlobalKey();
  final GlobalKey _humidityKey = GlobalKey();

  // Current readings (raw, before calibration offset)
  int _velocityRaw = 0; // FPM
  double _temperatureRaw = 0.0; // °F
  double _humidityRaw = 0.0; // %RH
  double _pressureRaw = 0.0; // in/WC

  // Smoothing buffers (5-sample moving average)
  final List<double> _tempBuffer = [];
  final List<double> _humidityBuffer = [];
  static const int _smoothingWindow = 5;

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
    await _calibrationService.init();
    _listenForDeviceUpdates();
    _listenForBatteryUpdates();
    await _checkForConnectedMeters();
  }

  // Getters that apply calibration offsets (temp/humidity/velocity only)
  // Pressure uses raw value - barometric doesn't need calibration
  int get _velocity =>
      _velocityRaw +
      _calibrationService.getOffset(Abm200CalibrationKeys.velocity).round();
  double get _temperature =>
      _temperatureRaw +
      _calibrationService.getOffset(Abm200CalibrationKeys.temperature);
  double get _humidity =>
      _humidityRaw +
      _calibrationService.getOffset(Abm200CalibrationKeys.humidity);
  double get _pressure => _pressureRaw;

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
      if (profile?.type == HvacDeviceType.airflowMeter) {
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

          // Check for ABM-200 or airflow meter
          final profile = _registry.identifyByName(deviceName);
          if (profile?.type == HvacDeviceType.airflowMeter) {
            await _bleService.stopScan();
            _scanSubscription?.cancel();

            if (!mounted) return;

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
                      Text('Connected to $deviceName'),
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
        final deviceName = _connectedDeviceName ?? 'Airflow Meter';
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

        final deviceName = _connectedDeviceName ?? 'Airflow Meter';
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

    // Listen for real-time readings
    _deviceUpdatesSubscription = _dataService.readings.listen((reading) {
      if (!mounted) return;

      // Only process airflow meter readings
      if (reading.type == HvacDeviceType.airflowMeter) {
        setState(() {
          _velocityRaw = reading.value.round();
          _connectedDeviceId = reading.deviceId;
          _connectedDeviceName = reading.deviceName;
          _isConnected = true;

          // Parse full ABM-200 multi-sensor data from rawData
          // Byte offsets reverse-engineered Dec 19, 2025:
          // [0-1] Velocity  [8-9] Humidity  [10-11] Temp  [12-13] Pressure
          if (reading.rawData != null && reading.rawData!.length >= 14) {
            final raw = reading.rawData!;
            final bytes = Uint8List.fromList(raw);
            final byteData = ByteData.view(bytes.buffer);

            // Bytes 0-1: Velocity (uint16 LE, FPM)
            _velocityRaw = byteData.getUint16(0, Endian.little);

            // Bytes 8-9: Humidity (uint16 LE ÷5.29 = %RH)
            // Divisor calibrated against CPS Link app Dec 19, 2025
            final humidityRaw = byteData.getUint16(8, Endian.little);
            final rawHumidity = humidityRaw / 5.29;
            // Add to smoothing buffer
            _humidityBuffer.add(rawHumidity);
            if (_humidityBuffer.length > _smoothingWindow)
              _humidityBuffer.removeAt(0);
            _humidityRaw = _humidityBuffer.reduce((a, b) => a + b) /
                _humidityBuffer.length;

            // Bytes 10-11: Temperature (uint16 LE × 1.6 = °F)
            // Testing new formula Dec 19, 2025: raw 43 × 1.6 = 68.8°F matches CPS 68.7°F
            final tempRaw = byteData.getUint16(10, Endian.little);
            final rawTemp = tempRaw * 1.6;
            // Add to smoothing buffer
            _tempBuffer.add(rawTemp);
            if (_tempBuffer.length > _smoothingWindow) _tempBuffer.removeAt(0);
            _temperatureRaw =
                _tempBuffer.reduce((a, b) => a + b) / _tempBuffer.length;

            // Bytes 12-13: Barometric Pressure (uint16 LE × 0.0401463 = in/WC)
            // Raw value is Pa/10, convert: Pa × 0.00401463 = in/WC
            final pressureRaw = byteData.getUint16(12, Endian.little);
            _pressureRaw = pressureRaw * 0.0401463;
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
        title: const Text('Airflow Meter'),
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
                            'Scanning for ABM-200 / TS-100...',
                            style: TextStyle(color: AppColors.primaryCyan),
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.warning, color: AppColors.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No airflow meter connected. Tap bluetooth icon to scan.',
                            style: TextStyle(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Main velocity display
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Large velocity reading - tappable for calibration
                      GestureDetector(
                        key: _velocityKey,
                        onTap: () => _showCalibrationPopup(
                          targetKey: _velocityKey,
                          sensorKey: Abm200CalibrationKeys.velocity,
                          label: 'Velocity',
                          currentValue: _velocityRaw.toDouble(),
                          step: 10,
                          unit: 'FPM',
                          accentColor: AppColors.primaryCyan,
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$_velocity',
                              style: TextStyle(
                                fontSize: 96,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              'FPM',
                              style: TextStyle(
                                fontSize: 32,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Secondary readings row - tappable for calibration
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSecondaryReading(
                            key: _tempKey,
                            icon: Icons.thermostat,
                            value: _temperature.isNaN
                                ? '--'
                                : _temperature.toStringAsFixed(1),
                            unit: '°F',
                            color: AppColors.error,
                            onTap: () => _showCalibrationPopup(
                              targetKey: _tempKey,
                              sensorKey: Abm200CalibrationKeys.temperature,
                              label: 'Temperature',
                              currentValue: _temperatureRaw,
                              step: 0.5,
                              unit: '°F',
                              accentColor: AppColors.error,
                            ),
                          ),
                          _buildSecondaryReading(
                            key: _humidityKey,
                            icon: Icons.water_drop,
                            value: _humidity.isNaN
                                ? '--'
                                : _humidity.toStringAsFixed(1),
                            unit: '%RH',
                            color: AppColors.accentBlue,
                            onTap: () => _showCalibrationPopup(
                              targetKey: _humidityKey,
                              sensorKey: Abm200CalibrationKeys.humidity,
                              label: 'Humidity',
                              currentValue: _humidityRaw,
                              step: 1.0,
                              unit: '%RH',
                              accentColor: AppColors.accentBlue,
                            ),
                          ),
                          // Pressure - not calibratable (barometric)
                          _buildStaticReading(
                            icon: Icons.compress,
                            value: _pressure.isNaN
                                ? '--'
                                : _pressure.toStringAsFixed(1),
                            unit: 'in/WC',
                            color: AppColors.primaryPurple,
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Connected device name with battery
                      if (_connectedDeviceName != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _connectedDeviceName!,
                              style: TextStyle(
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
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCalibrationPopup({
    required GlobalKey targetKey,
    required String sensorKey,
    required String label,
    required double currentValue,
    required double step,
    required String unit,
    required Color accentColor,
  }) {
    showCalibrationPopup(
      context: context,
      targetKey: targetKey,
      sensorKey: sensorKey,
      label: label,
      currentValue: currentValue,
      step: step,
      unit: unit,
      accentColor: accentColor,
      onSave: () {
        // Force rebuild to apply new offset
        setState(() {});
      },
    );
  }

  Widget _buildSecondaryReading({
    required GlobalKey key,
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Static reading display (not calibratable) - for pressure/barometric
  Widget _buildStaticReading({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
