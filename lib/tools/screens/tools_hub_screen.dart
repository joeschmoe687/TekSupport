import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../bluetooth/bluetooth_service.dart';
import '../../screens/support_contact_screen.dart';
import '../services/device_discovery_service.dart';
import '../services/device_storage_service.dart';
import '../services/auto_reconnect_service.dart';
import '../services/device_data_service.dart';
import 'gauge_screen.dart';
import 'scale_screen.dart';
import 'airflow_screen.dart';

/// Main Tools Hub screen - displays available HVAC tools
class ToolsHubScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const ToolsHubScreen({super.key, required this.onToggleTheme});

  @override
  State<ToolsHubScreen> createState() => _ToolsHubScreenState();
}

class _ToolsHubScreenState extends State<ToolsHubScreen> {
  final BluetoothService _bleService = BluetoothService();
  final DeviceDiscoveryService _discoveryService = DeviceDiscoveryService();
  final DeviceStorageService _storageService = DeviceStorageService();
  final AutoReconnectService _reconnectService = AutoReconnectService();
  final DeviceDataService _dataService = DeviceDataService();

  // Connected devices count
  int _connectedDeviceCount = 0;
  bool _hasScannedOnce = false;
  bool _isScanning = false;

  StreamSubscription? _deviceUpdatesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _bleService.init();
    await _storageService.init();
    await _dataService.init();
    await _reconnectService.init();
    _listenForDeviceUpdates();

    // Load saved device count (no auto-scan - let subscreens handle BLE)
    final savedDevices = await _storageService.getSavedDevices();
    if (mounted) {
      setState(() => _connectedDeviceCount = savedDevices.length);
    }
  }

  Future<void> _autoScanForDevices() async {
    if (_hasScannedOnce) return;
    _hasScannedOnce = true;

    // Check if we already have saved devices
    final savedDevices = await _storageService.getSavedDevices();
    if (savedDevices.isNotEmpty) {
      // Update connected count
      setState(() => _connectedDeviceCount = savedDevices.length);
      return; // Don't show popup if devices already saved
    }

    // Scan for compatible devices
    setState(() => _isScanning = true);

    final discovered = await _discoveryService.scanForDevices(
      timeout: const Duration(seconds: 4),
    );

    setState(() => _isScanning = false);

    // Show popup if we found compatible devices
    if (discovered.isNotEmpty && mounted) {
      _showDeviceDiscoveryPopup(discovered);
    }
  }

  void _showDeviceDiscoveryPopup(List<DiscoveredDevice> devices) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DeviceDiscoverySheet(
        devices: devices,
        onConnectAll: () => _connectToDevices(devices),
        onConnectSelected: (selected) => _connectToDevices(selected),
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _connectToDevices(List<DiscoveredDevice> devices) async {
    Navigator.pop(context); // Close the sheet

    int connected = 0;
    for (final device in devices) {
      try {
        // Connect to device
        await _bleService.connectToDevice(device.device);

        // Save to storage
        final savedDevice = SavedDevice(
          remoteId: device.deviceId,
          name: device.scanResult.device.platformName,
          manufacturer: device.profile.manufacturer.name,
          deviceType: device.profile.type.name,
          unit: device.profile.unit,
          firstPaired: DateTime.now(),
          lastSeen: DateTime.now(),
          autoReconnect: true,
        );
        await _storageService.saveDevice(savedDevice);

        // Mark as connected for auto-reconnect
        _reconnectService.markConnected(device.deviceId, device.device);

        // Subscribe to data
        await _dataService.subscribeToDevice(device.deviceId);

        connected++;
      } catch (e) {
        print('[ToolsHub] Failed to connect to ${device.displayName}: $e');
      }
    }

    setState(() => _connectedDeviceCount = connected);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Connected to $connected device${connected != 1 ? 's' : ''}!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _listenForDeviceUpdates() {
    // Listen to connected devices count
  }

  @override
  void dispose() {
    _deviceUpdatesSubscription?.cancel();
    super.dispose();
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
            const SizedBox(height: 24),
            Expanded(child: _buildToolsGrid()),
            const SizedBox(height: 8),
            _buildSupportButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TekTool',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (_isScanning)
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryCyan,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Scanning...',
                    style: TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                onPressed: () {
                  _hasScannedOnce = false;
                  _autoScanForDevices();
                },
                tooltip: 'Scan for devices',
              ),
          ],
        ),
        Text(
          _connectedDeviceCount > 0
              ? '$_connectedDeviceCount device${_connectedDeviceCount != 1 ? 's' : ''} connected'
              : 'No devices assigned',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildToolsGrid() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tools Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              _buildToolCard(
                title: 'Gauges',
                subtitle: 'Pressure & PT Chart',
                icon: Icons.speed,
                color: AppColors.primaryCyan,
                isAvailable: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          GaugeScreen(onToggleTheme: widget.onToggleTheme),
                    ),
                  );
                },
              ),
              _buildToolCard(
                title: 'Refrigerant Scale',
                subtitle: 'Weight tracking',
                icon: Icons.scale,
                color: AppColors.primaryPurple,
                isAvailable: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ScaleScreen(onToggleTheme: widget.onToggleTheme),
                    ),
                  );
                },
              ),
              _buildToolCard(
                title: 'Airflow Meter',
                subtitle: 'FPM, Temp, Humidity',
                icon: Icons.air,
                color: AppColors.accentBlue,
                isAvailable: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AirflowScreen(onToggleTheme: widget.onToggleTheme),
                    ),
                  );
                },
              ),
              _buildToolCard(
                title: 'Clamp Meter',
                subtitle: 'Electrical readings',
                icon: Icons.bolt,
                color: AppColors.warning,
                isAvailable: false,
                onTap: () => _showComingSoon('Clamp Meter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isAvailable,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAvailable ? color.withOpacity(0.3) : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (!isAvailable)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Soon',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color:
                    isAvailable ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isAvailable
                    ? AppColors.textSecondary
                    : AppColors.textMuted.withOpacity(0.7),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String toolName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$toolName coming soon!'),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSupportButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to support contact screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SupportContactScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primaryCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.support_agent),
        label: const Text('Get Help'),
      ),
    );
  }
}

/// Bottom sheet for device discovery
class _DeviceDiscoverySheet extends StatefulWidget {
  final List<DiscoveredDevice> devices;
  final VoidCallback onConnectAll;
  final Function(List<DiscoveredDevice>) onConnectSelected;
  final VoidCallback onDismiss;

  const _DeviceDiscoverySheet({
    required this.devices,
    required this.onConnectAll,
    required this.onConnectSelected,
    required this.onDismiss,
  });

  @override
  State<_DeviceDiscoverySheet> createState() => _DeviceDiscoverySheetState();
}

class _DeviceDiscoverySheetState extends State<_DeviceDiscoverySheet> {
  final Set<String> _selectedDevices = {};

  @override
  void initState() {
    super.initState();
    // Select all by default
    for (final device in widget.devices) {
      _selectedDevices.add(device.deviceId);
    }
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType) {
      case 'Temperature':
        return Icons.thermostat;
      case 'Pressure':
        return Icons.speed;
      case 'Scale':
        return Icons.scale;
      case 'Airflow':
        return Icons.air;
      case 'Electrical':
        return Icons.bolt;
      default:
        return Icons.bluetooth;
    }
  }

  Color _getDeviceColor(String deviceType) {
    switch (deviceType) {
      case 'Temperature':
        return AppColors.error;
      case 'Pressure':
        return AppColors.primaryCyan;
      case 'Scale':
        return AppColors.primaryPurple;
      case 'Airflow':
        return AppColors.accentBlue;
      case 'Electrical':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bluetooth_searching,
                  color: AppColors.success,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found ${widget.devices.length} Device${widget.devices.length != 1 ? 's' : ''}!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Compatible HVAC tools nearby',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Device list
          ...widget.devices.map((device) => _buildDeviceRow(device)),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onDismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Not Now'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _selectedDevices.isEmpty
                      ? null
                      : () {
                          final selected = widget.devices
                              .where(
                                  (d) => _selectedDevices.contains(d.deviceId))
                              .toList();
                          widget.onConnectSelected(selected);
                        },
                  icon: const Icon(Icons.bluetooth_connected),
                  label: Text(
                    _selectedDevices.length == widget.devices.length
                        ? 'Connect All'
                        : 'Connect (${_selectedDevices.length})',
                  ),
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

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildDeviceRow(DiscoveredDevice device) {
    final isSelected = _selectedDevices.contains(device.deviceId);
    final color = _getDeviceColor(device.deviceType);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDevices.remove(device.deviceId);
          } else {
            _selectedDevices.add(device.deviceId);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : AppColors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getDeviceIcon(device.deviceType),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.deviceType,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            // Signal strength indicator
            Row(
              children: [
                Icon(
                  Icons.signal_cellular_alt,
                  size: 16,
                  color: device.rssi > -60
                      ? AppColors.success
                      : device.rssi > -80
                          ? AppColors.warning
                          : AppColors.error,
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedDevices.add(device.deviceId);
                      } else {
                        _selectedDevices.remove(device.deviceId);
                      }
                    });
                  },
                  activeColor: color,
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
