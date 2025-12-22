import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../tools/services/device_data_service.dart';

/// Service that syncs live BLE device data to Firestore for web viewing
/// Only runs on mobile (not on web platform)
class LiveDataSyncService {
  static final LiveDataSyncService _instance = LiveDataSyncService._internal();
  factory LiveDataSyncService() => _instance;
  LiveDataSyncService._internal();

  final DeviceDataService _deviceDataService = DeviceDataService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  StreamSubscription? _readingsSubscription;
  StreamSubscription? _batterySubscription;
  StreamSubscription? _authSubscription;
  bool _isInitialized = false;
  String? _userId;
  
  // Throttling: Track last write time per device (max 1 write per second per device)
  final Map<String, DateTime> _lastWriteTime = {};
  static const _throttleDuration = Duration(seconds: 1);

  /// Initialize the sync service (only on mobile, not web)
  Future<void> init() async {
    if (_isInitialized || kIsWeb) return; // Don't run on web
    
    // Get current user ID
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    _userId = user.uid;
    _isInitialized = true;

    // Listen for auth state changes to cleanup on logout
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        // User logged out - cleanup
        dispose();
      } else if (user.uid != _userId) {
        // User changed - reinitialize
        dispose();
        init();
      }
    });

    // Subscribe to device readings and push to Firestore with throttling
    _readingsSubscription = _deviceDataService.readings.listen((reading) {
      _syncReadingThrottled(reading);
    });

    // Subscribe to battery updates with throttling
    _batterySubscription = _deviceDataService.batteryUpdates.listen((battery) {
      _syncBatteryThrottled(battery);
    });

    debugPrint('[LiveDataSync] Started syncing data for user $_userId');
  }

  /// Throttled sync for device reading (max 1 write per second per device)
  void _syncReadingThrottled(DeviceReading reading) {
    final now = DateTime.now();
    final lastWrite = _lastWriteTime[reading.deviceId];
    
    if (lastWrite == null || now.difference(lastWrite) >= _throttleDuration) {
      _lastWriteTime[reading.deviceId] = now;
      _syncReading(reading);
    }
    // Else: Skip this reading to avoid excessive writes
  }

  /// Throttled sync for battery update (max 1 write per second per device)
  void _syncBatteryThrottled(BatteryReading battery) {
    final now = DateTime.now();
    final key = '${battery.deviceId}_battery';
    final lastWrite = _lastWriteTime[key];
    
    if (lastWrite == null || now.difference(lastWrite) >= _throttleDuration) {
      _lastWriteTime[key] = now;
      _syncBattery(battery);
    }
    // Else: Skip this update to avoid excessive writes
  }

  /// Sync a device reading to Firestore
  Future<void> _syncReading(DeviceReading reading) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('live_device_data')
          .doc(_userId)
          .collection('readings')
          .doc(reading.deviceId)
          .set({
        'deviceId': reading.deviceId,
        'deviceName': reading.deviceName,
        'type': reading.type.name,
        'value': reading.value,
        'unit': reading.unit,
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[LiveDataSync] Failed to sync reading: $e');
    }
  }

  /// Sync battery level to Firestore
  Future<void> _syncBattery(BatteryReading battery) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('live_device_data')
          .doc(_userId)
          .collection('readings')
          .doc(battery.deviceId)
          .set({
        'batteryLevel': battery.level,
        'batteryUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[LiveDataSync] Failed to sync battery: $e');
    }
  }

  /// Update connected devices list
  Future<void> updateConnectedDevices(List<String> deviceIds) async {
    if (_userId == null || kIsWeb) return;

    try {
      await _firestore
          .collection('live_device_data')
          .doc(_userId)
          .set({
        'connectedDevices': deviceIds,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[LiveDataSync] Failed to update connected devices: $e');
    }
  }

  /// Cleanup
  Future<void> dispose() async {
    await _readingsSubscription?.cancel();
    await _batterySubscription?.cancel();
    await _authSubscription?.cancel();
    _lastWriteTime.clear();
    _isInitialized = false;
    _userId = null;
  }
}
