import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'device_storage_service.dart';

/// Service for automatically reconnecting to previously paired BLE devices.
/// Runs background scans to find and reconnect to known devices.
class AutoReconnectService {
  static final AutoReconnectService _instance =
      AutoReconnectService._internal();
  factory AutoReconnectService() => _instance;
  AutoReconnectService._internal();

  final DeviceStorageService _storage = DeviceStorageService();

  // Currently connected device IDs
  final Set<String> _connectedDeviceIds = {};

  // Devices we're trying to reconnect to
  final Set<String> _pendingReconnects = {};

  // Stream controllers
  final _reconnectStatusController =
      StreamController<ReconnectStatus>.broadcast();

  // Subscriptions
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _backgroundScanTimer;

  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isPaused = false; // Allow user to temporarily pause auto-reconnect

  /// Stream of reconnect status updates
  Stream<ReconnectStatus> get reconnectStatus =>
      _reconnectStatusController.stream;

  /// Currently connected device IDs
  Set<String> get connectedDeviceIds => Set.unmodifiable(_connectedDeviceIds);

  /// Check if auto-reconnect is paused
  bool get isPaused => _isPaused;

  /// Check if a device is connected
  bool isConnected(String remoteId) => _connectedDeviceIds.contains(remoteId);

  /// Pause auto-reconnect temporarily (useful when user wants to connect via other apps)
  void pause() {
    _isPaused = true;
    stopBackgroundScanning();
  }

  /// Resume auto-reconnect
  void resume() {
    _isPaused = false;
    if (_isInitialized) {
      _startBackgroundScanning();
    }
  }

  /// Initialize the auto-reconnect service
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _storage.init();

    // Listen for scan results
    _scanSubscription = ble.FlutterBluePlus.scanResults.listen(_onScanResults);

    // Start background scanning for known devices
    _startBackgroundScanning();

    // Listen for existing connections
    _monitorConnections();
  }

  /// Start periodic background scanning for known devices
  void _startBackgroundScanning() {
    // Cancel any existing timer
    _backgroundScanTimer?.cancel();

    // Scan every 60 seconds for known devices that aren't connected
    // (Reduced frequency to be less aggressive)
    _backgroundScanTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (!_isPaused) {
          _scanForKnownDevices();
        }
      },
    );

    // Do initial scan after 5 seconds (give user time to navigate)
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isPaused && _isInitialized) {
        _scanForKnownDevices();
      }
    });
  }

  /// Stop background scanning
  void stopBackgroundScanning() {
    _backgroundScanTimer?.cancel();
    _backgroundScanTimer = null;
  }

  /// Scan for known devices that need reconnection
  Future<void> _scanForKnownDevices() async {
    if (_isScanning || _isPaused) return;

    try {
      final state = await ble.FlutterBluePlus.adapterState.first;
      if (state != ble.BluetoothAdapterState.on) return;

      final savedDevices = await _storage.getSavedDevices();
      if (savedDevices.isEmpty) return;

      // Find devices that need reconnection
      final needsReconnect = savedDevices
          .where((d) =>
              d.autoReconnect && !_connectedDeviceIds.contains(d.remoteId))
          .toList();

      if (needsReconnect.isEmpty) return;

      // Update pending reconnects
      _pendingReconnects.clear();
      _pendingReconnects.addAll(needsReconnect.map((d) => d.remoteId));

      _isScanning = true;
      _reconnectStatusController.add(ReconnectStatus(
        state: ReconnectState.scanning,
        message: 'Scanning for ${needsReconnect.length} device(s)...',
      ));

      // Quick scan to find known devices
      await ble.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      _reconnectStatusController.add(ReconnectStatus(
        state: ReconnectState.error,
        message: 'Scan failed: $e',
      ));
    } finally {
      _isScanning = false;
    }
  }

  /// Handle scan results - look for known devices
  void _onScanResults(List<ble.ScanResult> results) async {
    if (_pendingReconnects.isEmpty) return;

    for (final result in results) {
      final remoteId = result.device.remoteId.str;

      if (_pendingReconnects.contains(remoteId) &&
          !_connectedDeviceIds.contains(remoteId)) {
        // Found a known device - attempt reconnect
        _pendingReconnects.remove(remoteId);
        await _attemptReconnect(result.device);
      }
    }
  }

  /// Attempt to reconnect to a device with retry logic
  /// Uses exponential backoff to handle Android GATT 133 errors gracefully
  Future<bool> _attemptReconnect(ble.BluetoothDevice device,
      {int maxRetries = 3}) async {
    final remoteId = device.remoteId.str;
    final deviceName =
        device.platformName.isNotEmpty ? device.platformName : remoteId;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      _reconnectStatusController.add(ReconnectStatus(
        state: ReconnectState.connecting,
        message: attempt > 1
            ? 'Connecting to $deviceName (attempt $attempt/$maxRetries)...'
            : 'Connecting to $deviceName...',
        deviceId: remoteId,
      ));

      try {
        // Clear GATT cache before retry (helps with Android 133 errors)
        if (attempt > 1) {
          try {
            await device.clearGattCache();
          } catch (_) {
            // Ignore - not all platforms support this
          }
        }

        await device.connect(
          timeout: const Duration(seconds: 15),
          autoConnect: false,
        );

        // Discover services
        await device.discoverServices();

        _connectedDeviceIds.add(remoteId);

        // Update last seen
        await _storage.updateLastSeen(remoteId);

        // Log connection event
        await _storage.logConnection(ConnectionEvent(
          remoteId: remoteId,
          deviceName: device.platformName,
          timestamp: DateTime.now(),
          eventType: 'connected',
          reason: attempt > 1
              ? 'auto-reconnect (retry $attempt)'
              : 'auto-reconnect',
        ));

        _reconnectStatusController.add(ReconnectStatus(
          state: ReconnectState.connected,
          message: 'Connected to ${device.platformName}',
          deviceId: remoteId,
        ));

        // Monitor this connection
        _monitorDevice(device);

        return true;
      } catch (e) {
        final isLastAttempt = attempt == maxRetries;
        final errorStr = e.toString();

        // Check if it's a GATT 133 error (common Android flakiness)
        final isGatt133 = errorStr.contains('133') ||
            errorStr.contains('ANDROID_SPECIFIC_ERROR');

        if (!isLastAttempt && isGatt133) {
          // Exponential backoff: 1s, 2s, 4s
          final delay = Duration(seconds: 1 << (attempt - 1));
          await Future.delayed(delay);
          continue; // Try again
        }

        // Final failure - log and report
        await _storage.logConnection(ConnectionEvent(
          remoteId: remoteId,
          deviceName: device.platformName,
          timestamp: DateTime.now(),
          eventType: 'failed',
          reason: isGatt133
              ? 'GATT 133 error after $attempt attempts'
              : e.toString(),
        ));

        _reconnectStatusController.add(ReconnectStatus(
          state: ReconnectState.error,
          message: isGatt133
              ? 'Connection unstable - try again in a moment'
              : 'Failed to connect: $e',
          deviceId: remoteId,
        ));

        return false;
      }
    }

    return false;
  }

  /// Monitor a connected device for disconnection
  void _monitorDevice(ble.BluetoothDevice device) {
    device.connectionState.listen((state) async {
      final remoteId = device.remoteId.str;

      if (state == ble.BluetoothConnectionState.disconnected) {
        _connectedDeviceIds.remove(remoteId);

        // Log disconnection
        await _storage.logConnection(ConnectionEvent(
          remoteId: remoteId,
          deviceName: device.platformName,
          timestamp: DateTime.now(),
          eventType: 'disconnected',
        ));

        _reconnectStatusController.add(ReconnectStatus(
          state: ReconnectState.disconnected,
          message: '${device.platformName} disconnected',
          deviceId: remoteId,
        ));

        // Add back to pending reconnects if auto-reconnect is enabled
        final savedDevices = await _storage.getSavedDevices();
        final saved =
            savedDevices.where((d) => d.remoteId == remoteId).firstOrNull;
        if (saved?.autoReconnect ?? false) {
          _pendingReconnects.add(remoteId);
          // Trigger a quick scan
          Future.delayed(const Duration(seconds: 2), _scanForKnownDevices);
        }
      } else if (state == ble.BluetoothConnectionState.connected) {
        _connectedDeviceIds.add(remoteId);
      }
    });
  }

  /// Monitor all existing connections on startup
  void _monitorConnections() {
    // Check currently connected devices (connectedDevices is now a sync getter)
    final devices = ble.FlutterBluePlus.connectedDevices;
    for (final device in devices) {
      _connectedDeviceIds.add(device.remoteId.str);
      _monitorDevice(device);
    }
  }

  /// Manually trigger reconnection for a specific device
  Future<bool> reconnectDevice(String remoteId) async {
    try {
      final device = ble.BluetoothDevice.fromId(remoteId);
      return await _attemptReconnect(device);
    } catch (e) {
      _reconnectStatusController.add(ReconnectStatus(
        state: ReconnectState.error,
        message: 'Reconnect failed: $e',
        deviceId: remoteId,
      ));
      return false;
    }
  }

  /// Force a scan for all known devices
  Future<void> scanForAllDevices() async {
    await _scanForKnownDevices();
  }

  /// Mark a device as connected (called when manually connecting)
  void markConnected(String remoteId, ble.BluetoothDevice device) {
    _connectedDeviceIds.add(remoteId);
    _pendingReconnects.remove(remoteId);
    _monitorDevice(device);

    // Emit connected status so DeviceDataService subscribes to data
    _reconnectStatusController.add(ReconnectStatus(
      state: ReconnectState.connected,
      message: 'Connected to ${device.platformName}',
      deviceId: remoteId,
    ));
  }

  /// Mark a device as disconnected
  void markDisconnected(String remoteId) {
    _connectedDeviceIds.remove(remoteId);
  }

  /// Dispose resources
  void dispose() {
    _backgroundScanTimer?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _reconnectStatusController.close();
    _isInitialized = false;
  }
}

/// State of the reconnect process
enum ReconnectState {
  idle,
  scanning,
  connecting,
  connected,
  disconnected,
  error,
}

/// Status update for reconnection
class ReconnectStatus {
  final ReconnectState state;
  final String message;
  final String? deviceId;

  ReconnectStatus({
    required this.state,
    required this.message,
    this.deviceId,
  });
}
