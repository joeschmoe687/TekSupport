import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import '../../widgets/gradient_scaffold.dart';
import '../../bluetooth/bluetooth_service.dart';
import '../services/device_registry.dart';
import '../services/auto_reconnect_service.dart';
import '../services/device_data_service.dart';
import '../models/connected_device.dart';

/// Device Scan screen - scans for and connects to HVAC Bluetooth tools
class DeviceScanScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const DeviceScanScreen({super.key, required this.onToggleTheme});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  final BluetoothService _bleService = BluetoothService();
  final DeviceRegistry _deviceRegistry = DeviceRegistry();
  final AutoReconnectService _reconnectService = AutoReconnectService();
  final DeviceDataService _dataService = DeviceDataService();

  List<ble.ScanResult> _scanResults = [];
  bool _isScanning = false;
  String? _connectingDeviceId;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _stopScan();
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (!await _bleService.isBluetoothAvailable()) {
      _showBluetoothOffDialog();
      return;
    }

    setState(() {
      _isScanning = true;
      _scanResults = [];
    });

    _scanSubscription = ble.FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        // Filter to show devices with names (likely HVAC tools)
        _scanResults = results.where((r) {
          final name = r.device.platformName;
          return name.isNotEmpty;
        }).toList();

        // Sort by signal strength
        _scanResults.sort((a, b) => b.rssi.compareTo(a.rssi));
      });
    });

    _isScanningSubscription = ble.FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return;
      setState(() => _isScanning = scanning);
    });

    try {
      await _bleService.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      _showError('Scan failed: $e');
      setState(() => _isScanning = false);
    }
  }

  Future<void> _stopScan() async {
    await _bleService.stopScan();
  }

  void _showBluetoothOffDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: AppColors.error),
            SizedBox(width: 12),
            Text('Bluetooth Off',
                style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          'Please turn on Bluetooth to scan for HVAC tools.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _bleService.requestBluetoothOn();
            },
            child: const Text('Turn On'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _connectToDevice(ble.ScanResult result) async {
    setState(() => _connectingDeviceId = result.device.remoteId.str);

    try {
      await _bleService.connectToDevice(result.device);

      // Notify AutoReconnectService to track this connection
      _reconnectService.markConnected(
        result.device.remoteId.str,
        result.device,
      );

      // Subscribe to data notifications
      await _dataService.init();
      await _dataService.subscribeToDevice(result.device.remoteId.str);

      // Identify the device type from registry
      final profile = _deviceRegistry.identifyDevice(result);

      final connectedDevice = ConnectedDevice(
        id: result.device.remoteId.str,
        name: result.device.platformName.isNotEmpty
            ? result.device.platformName
            : 'Unknown Device',
        manufacturer: profile?.manufacturer ?? HvacManufacturer.unknown,
        type: profile?.type ?? HvacDeviceType.unknown,
        unit: profile?.unit ?? '',
        isConnected: true,
      );

      if (mounted) {
        Navigator.pop(context, connectedDevice);
      }
    } catch (e) {
      _showError('Connection failed: $e');
    } finally {
      setState(() => _connectingDeviceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scan for Devices',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryCyan,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh, color: AppColors.primaryCyan),
              onPressed: _startScan,
              tooltip: 'Rescan',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScanStatus(),
            Expanded(child: _buildDevicesList()),
          ],
        ),
      ),
    );
  }

  Widget _buildScanStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isScanning ? 'Scanning...' : 'Scan Complete',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _scanResults.isEmpty
                ? 'Make sure your devices are powered on and in pairing mode'
                : '${_scanResults.length} device${_scanResults.length == 1 ? '' : 's'} found',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (_isScanning) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              backgroundColor: AppColors.border,
              color: AppColors.primaryCyan,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    if (_scanResults.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _scanResults.length,
      itemBuilder: (context, index) {
        final result = _scanResults[index];
        return _buildDeviceCard(result,
            key: ValueKey(result.device.remoteId.str));
      },
    );
  }

  Widget _buildEmptyState() {
    if (_isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 60,
              color: AppColors.primaryCyan,
            ),
            SizedBox(height: 16),
            Text(
              'Looking for devices...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_disabled,
            size: 60,
            color: AppColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Devices Found',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your HVAC tools are\npowered on and nearby',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _startScan,
            icon: const Icon(Icons.refresh),
            label: const Text('Scan Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(ble.ScanResult result, {Key? key}) {
    final isConnecting = _connectingDeviceId == result.device.remoteId.str;
    final rssi = result.rssi;
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : 'Unknown Device';

    // Check if this is a known HVAC tool
    final profile = _deviceRegistry.identifyDevice(result);
    final isKnownDevice = profile != null;
    final isBroadcastOnly = profile?.isBroadcastOnly ?? false;

    return Container(
      key: key ?? ValueKey(result.device.remoteId.str),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isKnownDevice
            ? AppColors.primaryCyan.withOpacity(0.1)
            : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isKnownDevice
              ? AppColors.primaryCyan.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isKnownDevice ? _getDeviceIcon(profile.type) : Icons.bluetooth,
            color:
                isKnownDevice ? AppColors.primaryCyan : AppColors.textSecondary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isKnownDevice)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'SUPPORTED',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _buildSignalIcon(rssi),
                const SizedBox(width: 8),
                Text(
                  '$rssi dBm',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                if (isKnownDevice) ...[
                  const SizedBox(width: 16),
                  Text(
                    profile.name,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            if (isBroadcastOnly) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.broadcast_on_personal,
                      size: 12, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Broadcast-only (reads from advertisement)',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              // Display Fieldpiece readings from manufacturer data
              if (result.advertisementData.manufacturerData.containsKey(0x5046))
                _buildFieldpieceReadings(
                    result.advertisementData.manufacturerData[0x5046]!),
            ],
          ],
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryCyan,
                ),
              )
            : isBroadcastOnly
                ? Icon(Icons.sensors, color: AppColors.warning, size: 24)
                : IconButton(
                    icon: const Icon(Icons.add_circle,
                        color: AppColors.primaryCyan),
                    onPressed: () => _connectToDevice(result),
                    tooltip: 'Connect',
                  ),
        onTap: (isConnecting || isBroadcastOnly)
            ? null
            : () => _connectToDevice(result),
      ),
    );
  }

  Widget _buildSignalIcon(int rssi) {
    Color color;
    IconData icon;

    if (rssi >= -60) {
      color = AppColors.success;
      icon = Icons.signal_cellular_4_bar;
    } else if (rssi >= -75) {
      color = AppColors.warning;
      icon = Icons.signal_cellular_alt;
    } else {
      color = AppColors.error;
      icon = Icons.signal_cellular_alt_1_bar;
    }

    return Icon(icon, size: 16, color: color);
  }

  IconData _getDeviceIcon(HvacDeviceType type) {
    switch (type) {
      case HvacDeviceType.refrigerantScale:
        return Icons.scale;
      case HvacDeviceType.temperatureProbe:
        return Icons.thermostat;
      case HvacDeviceType.airflowMeter:
        return Icons.air;
      case HvacDeviceType.pressureProbe:
        return Icons.compress;
      case HvacDeviceType.refrigerantGauge:
        return Icons.speed;
      case HvacDeviceType.clampMeter:
        return Icons.bolt;
      case HvacDeviceType.vacuumGauge:
        return Icons.speed;
      default:
        return Icons.devices;
    }
  }

  /// Build Fieldpiece readings display from manufacturer data
  Widget _buildFieldpieceReadings(List<int> manufacturerData) {
    if (manufacturerData.length < 4) {
      return const SizedBox.shrink();
    }

    // Get device type and readings
    final deviceTypeCode = String.fromCharCodes(manufacturerData.sublist(2, 4));
    String reading = '';

    try {
      switch (deviceTypeCode) {
        case 'BF': // Temperature Clamp
          final temp = parseFieldpieceTemp(manufacturerData);
          if (!temp.isNaN) {
            reading = '${temp.toStringAsFixed(1)}°F';
          }
          break;

        case 'BG': // Pressure Probe
          final pressure = parseFieldpiecePressure(manufacturerData);
          if (!pressure.isNaN) {
            reading = '${pressure.toStringAsFixed(1)} psig';
          }
          break;

        case 'BH': // Psychrometer
          final readings = parseFieldpiecePsychrometerFull(manufacturerData);
          final wetBulb = readings['wetBulb'] ?? double.nan;
          final dryBulb = readings['dryBulb'] ?? double.nan;
          
          List<String> parts = [];
          if (!dryBulb.isNaN) {
            parts.add('DB: ${dryBulb.toStringAsFixed(1)}°F');
          }
          if (!wetBulb.isNaN) {
            parts.add('WB: ${wetBulb.toStringAsFixed(1)}°F');
          }
          
          if (parts.isNotEmpty) {
            reading = parts.join(', ');
          }
          break;

        case 'CB': // SC680 Meter
          final value = parseFieldpieceSC680(manufacturerData);
          if (!value.isNaN) {
            reading = '${value.toStringAsFixed(1)}A';
          }
          break;
      }
    } catch (e) {
      // Ignore parsing errors
    }

    if (reading.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryCyan.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.primaryCyan.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.sensors,
            size: 12,
            color: AppColors.primaryCyan,
          ),
          const SizedBox(width: 4),
          Text(
            reading,
            style: const TextStyle(
              color: AppColors.primaryCyan,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
