import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/gradient_scaffold.dart';
import '../services/device_registry.dart';
import '../services/device_storage_service.dart';
import '../services/auto_reconnect_service.dart';
import '../services/device_data_service.dart';
import '../models/connected_device.dart';
import 'device_scan_screen.dart';
import 'ble_sniffer_screen.dart';
import 'airflow_screen.dart';

/// Devices screen - shows paired/connected BLE HVAC tools
class DevicesScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const DevicesScreen({super.key, required this.onToggleTheme});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final DeviceStorageService _storageService = DeviceStorageService();
  final AutoReconnectService _reconnectService = AutoReconnectService();
  final DeviceDataService _dataService = DeviceDataService();

  // Saved devices from storage
  List<SavedDevice> _savedDevices = [];

  // Currently connected devices
  final List<ConnectedDevice> _connectedDevices = [];

  bool _isReconnecting = false;
  bool _isAdmin = false;
  String? _reconnectingDeviceId;

  StreamSubscription? _reconnectStatusSub;
  StreamSubscription? _batterySubscription;

  @override
  void initState() {
    super.initState();
    _initServices();
    _checkAdminStatus();
  }

  Future<void> _initServices() async {
    await _storageService.init();
    await _reconnectService.init();
    await _dataService.init();
    await _loadSavedDevices();

    // Listen for reconnect status updates
    _reconnectStatusSub = _reconnectService.reconnectStatus.listen((status) {
      if (!mounted) return;

      if (status.state == ReconnectState.connected && status.deviceId != null) {
        // Refresh device list when auto-reconnected
        _loadSavedDevices();
      } else if (status.state == ReconnectState.disconnected &&
          status.deviceId != null) {
        // Update device list when disconnected
        _loadSavedDevices();
      }

      setState(() {
        _isReconnecting = status.state == ReconnectState.connecting ||
            status.state == ReconnectState.scanning;
        _reconnectingDeviceId = status.deviceId;
      });
    });

    // Listen for battery level updates
    _batterySubscription = _dataService.batteryUpdates.listen((battery) {
      if (!mounted) return;

      // Update battery level for matching device
      setState(() {
        for (final device in _connectedDevices) {
          if (device.id == battery.deviceId) {
            device.batteryLevel = battery.level;
            break;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _reconnectStatusSub?.cancel();
    _batterySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      final role = (data['role'] ?? '').toString().toLowerCase();

      if (mounted) {
        setState(() {
          _isAdmin = role == 'admin';
        });
      }
    } catch (_) {
      // Silently fail - not admin
    }
  }

  Future<void> _loadSavedDevices() async {
    final devices = await _storageService.getSavedDevices();

    if (!mounted) return;

    setState(() {
      _savedDevices = devices;

      // Convert saved devices to ConnectedDevice for display
      // Only show known working device types (filter out unknown)
      _connectedDevices.clear();
      for (final saved in devices) {
        final deviceType = _parseDeviceType(saved.deviceType);
        // Skip unknown device types - only show known working devices
        if (deviceType == HvacDeviceType.unknown) continue;

        final isConnected = _reconnectService.isConnected(saved.remoteId);
        final batteryLevel = _dataService.getBatteryLevel(saved.remoteId);
        _connectedDevices.add(ConnectedDevice(
          id: saved.remoteId,
          name: saved.name,
          manufacturer: _parseManufacturer(saved.manufacturer),
          type: deviceType,
          unit: saved.unit,
          isConnected: isConnected,
          batteryLevel: batteryLevel,
        ));
      }
    });
  }

  HvacManufacturer _parseManufacturer(String name) {
    switch (name.toLowerCase()) {
      case 'testo':
        return HvacManufacturer.testo;
      case 'fieldpiece':
        return HvacManufacturer.fieldpiece;
      case 'ccs':
        return HvacManufacturer.ccs;
      case 'weytek':
        return HvacManufacturer.weytek;
      case 'parker':
        return HvacManufacturer.parker;
      case 'yellowjacket':
      case 'yellow jacket':
        return HvacManufacturer.yellowJacket;
      default:
        return HvacManufacturer.unknown;
    }
  }

  HvacDeviceType _parseDeviceType(String type) {
    switch (type.toLowerCase()) {
      case 'temperatureprobe':
      case 'temperature_probe':
        return HvacDeviceType.temperatureProbe;
      case 'pressureprobe':
      case 'pressure_probe':
        return HvacDeviceType.pressureProbe;
      case 'refrigerantscale':
      case 'refrigerant_scale':
        return HvacDeviceType.refrigerantScale;
      case 'airflowmeter':
      case 'airflow_meter':
        return HvacDeviceType.airflowMeter;
      case 'clampmeter':
      case 'clamp_meter':
        return HvacDeviceType.clampMeter;
      case 'vacuumgauge':
      case 'vacuum_gauge':
        return HvacDeviceType.vacuumGauge;
      case 'refrigerantgauge':
      case 'refrigerant_gauge':
        return HvacDeviceType.refrigerantGauge;
      default:
        return HvacDeviceType.unknown;
    }
  }

  Future<void> _reconnectToDevice(String deviceId) async {
    setState(() {
      _isReconnecting = true;
      _reconnectingDeviceId = deviceId;
    });

    try {
      final success = await _reconnectService.reconnectDevice(deviceId);

      if (success) {
        await _loadSavedDevices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device connected'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      _showError('Failed to reconnect: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isReconnecting = false;
          _reconnectingDeviceId = null;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _forgetDevice(String deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Forget Device?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will remove the device from your saved list. You can scan for it again anytime.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Forget'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storageService.removeDevice(deviceId);
      setState(() {
        _savedDevices.removeWhere((d) => d.remoteId == deviceId);
        _connectedDevices.removeWhere((d) => d.id == deviceId);
      });
    }
  }

  void _navigateToScan() async {
    final result = await Navigator.push<ConnectedDevice?>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DeviceScanScreen(onToggleTheme: widget.onToggleTheme),
      ),
    );

    if (result != null) {
      // Save device to storage
      final savedDevice = SavedDevice(
        remoteId: result.id,
        name: result.name,
        manufacturer: result.manufacturer.name,
        deviceType: result.type.name,
        unit: result.unit,
        firstPaired: DateTime.now(),
        lastSeen: DateTime.now(),
        autoReconnect: true,
      );

      await _storageService.saveDevice(savedDevice);

      // Log connection event
      await _storageService.logConnection(ConnectionEvent(
        remoteId: result.id,
        deviceName: result.name,
        timestamp: DateTime.now(),
        eventType: 'connected',
        reason: 'manual_pair',
      ));

      // Reload device list
      await _loadSavedDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Expanded(child: _buildDevicesList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Devices',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Manage your Bluetooth tools',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Admin-only BLE Sniffer button
        if (_isAdmin)
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BleSnifferScreen(),
                ),
              );
            },
            icon: const Icon(Icons.developer_mode, size: 28),
            color: AppColors.warning,
            tooltip: 'BLE Sniffer (Admin)',
          ),
        IconButton(
          onPressed: _navigateToScan,
          icon: const Icon(Icons.add_circle, size: 32),
          color: AppColors.primaryCyan,
          tooltip: 'Add Device',
        ),
      ],
    );
  }

  Widget _buildDevicesList() {
    if (_connectedDevices.isEmpty && _savedDevices.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _reconnectService.scanForAllDevices();
        await _loadSavedDevices();
      },
      color: AppColors.primaryCyan,
      child: ListView.builder(
        itemCount: _connectedDevices.length,
        itemBuilder: (context, index) {
          final device = _connectedDevices[index];
          return _buildDeviceCard(device);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bluetooth,
                size: 80,
                color: AppColors.textMuted.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Devices Yet',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your Bluetooth HVAC tools\nto start taking readings',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _navigateToScan,
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Scan for Devices'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(ConnectedDevice device) {
    return Dismissible(
      key: Key(device.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _forgetDevice(device.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: device.isConnected
                ? AppColors.success.withOpacity(0.5)
                : AppColors.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            onTap: device.isConnected &&
                    device.type == HvacDeviceType.airflowMeter
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AirflowScreen(onToggleTheme: widget.onToggleTheme),
                      ),
                    )
                : null,
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getDeviceIcon(device.type),
                color: AppColors.primaryCyan,
              ),
            ),
            title: Text(
              device.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  device.manufacturerName,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: device.isConnected
                            ? AppColors.success
                            : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      device.isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: device.isConnected
                            ? AppColors.success
                            : AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    if (device.batteryLevel != null) ...[
                      const SizedBox(width: 16),
                      Icon(
                        _getBatteryIcon(device.batteryLevel!),
                        size: 16,
                        color: _getBatteryColor(device.batteryLevel!),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${device.batteryLevel}%',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: device.isConnected
                ? Text(
                    device.displayReading,
                    style: const TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : IconButton(
                    icon:
                        (_isReconnecting && _reconnectingDeviceId == device.id)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryCyan,
                                ),
                              )
                            : const Icon(Icons.bluetooth_connected,
                                color: AppColors.primaryCyan),
                    onPressed:
                        (_isReconnecting && _reconnectingDeviceId == device.id)
                            ? null
                            : () => _reconnectToDevice(device.id),
                    tooltip: 'Reconnect',
                  ),
          ),
        ),
      ),
    );
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

  IconData _getBatteryIcon(int level) {
    if (level >= 80) return Icons.battery_full;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 40) return Icons.battery_4_bar;
    if (level >= 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor(int level) {
    if (level >= 50) return AppColors.success;
    if (level >= 20) return AppColors.warning;
    return AppColors.error;
  }
}
