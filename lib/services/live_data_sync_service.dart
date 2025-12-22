import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../tools/services/device_data_service.dart';
import '../tools/services/device_registry.dart';

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
  bool _isInitialized = false;
  String? _userId;

  /// Initialize the sync service (only on mobile, not web)
  Future<void> init() async {
    if (_isInitialized || kIsWeb) return; // Don't run on web
    
    // Get current user ID
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    _userId = user.uid;
    _isInitialized = true;

    // Subscribe to device readings and push to Firestore
    _readingsSubscription = _deviceDataService.readings.listen((reading) {
      _syncReading(reading);
    });

    // Subscribe to battery updates
    _batterySubscription = _deviceDataService.batteryUpdates.listen((battery) {
      _syncBattery(battery);
    });

    debugPrint('[LiveDataSync] Started syncing data for user $_userId');
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
    _isInitialized = false;
  }
}
