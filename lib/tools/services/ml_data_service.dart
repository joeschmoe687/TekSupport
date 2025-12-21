import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hvac_reading.dart';
import '../screens/gauge_screen.dart';
import '../services/refrigerant_detector.dart';

/// Service for collecting and uploading ML training data to Firebase
class MLDataService {
  static final MLDataService _instance = MLDataService._internal();
  factory MLDataService() => _instance;
  MLDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Batch readings during job
  final List<HvacReading> _pendingReadings = [];
  
  // Privacy setting key
  static const String _mlDataSharingKey = 'ml_data_sharing_enabled';
  
  bool _isInitialized = false;
  bool _mlDataSharingEnabled = true; // Default to enabled

  /// Initialize the service and load privacy preferences
  Future<void> init() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    _mlDataSharingEnabled = prefs.getBool(_mlDataSharingKey) ?? true;
    
    _isInitialized = true;
  }

  /// Check if ML data sharing is enabled
  bool get isMLDataSharingEnabled => _mlDataSharingEnabled;

  /// Toggle ML data sharing preference
  Future<void> setMLDataSharing(bool enabled) async {
    _mlDataSharingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mlDataSharingKey, enabled);
  }

  /// Capture a snapshot of current gauge readings
  /// This creates a reading but doesn't upload it immediately
  HvacReading captureReading({
    String? jobId,
    required JobType systemType,
    required Refrigerant refrigerant,
    String? equipmentInfo,
    bool? isFixedOrifice,
    double? suctionPressure,
    double? dischargePressure,
    double? suctionLineTemp,
    double? liquidLineTemp,
    double? supplyAirTemp,
    double? returnAirTemp,
    double? ambientTemp,
    double? superheat,
    double? subcool,
    ReadingOutcome? outcome,
    String? technicianNotes,
    List<String>? adjustmentsMade,
  }) {
    final user = _auth.currentUser;
    
    final reading = HvacReading(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      jobId: jobId,
      technicianId: _mlDataSharingEnabled ? user?.uid : null,
      timestamp: DateTime.now(),
      systemType: systemType,
      refrigerant: refrigerant,
      equipmentInfo: equipmentInfo,
      isFixedOrifice: isFixedOrifice,
      suctionPressure: suctionPressure,
      dischargePressure: dischargePressure,
      suctionLineTemp: suctionLineTemp,
      liquidLineTemp: liquidLineTemp,
      supplyAirTemp: supplyAirTemp,
      returnAirTemp: returnAirTemp,
      ambientTemp: ambientTemp,
      superheat: superheat,
      subcool: subcool,
      outcome: outcome,
      technicianNotes: technicianNotes,
      adjustmentsMade: adjustmentsMade,
      isAnonymized: true, // Always anonymize
    );
    
    // Add to pending batch
    _pendingReadings.add(reading);
    
    return reading;
  }

  /// Upload a single reading immediately
  Future<void> uploadReading(HvacReading reading) async {
    if (!_mlDataSharingEnabled) {
      return; // User has opted out
    }

    try {
      await _firestore
          .collection('ml_hvac_readings')
          .doc(reading.id)
          .set(reading.toFirestore());
    } catch (e) {
      print('Error uploading ML reading: $e');
      // Don't throw - ML data upload failures shouldn't block user workflow
    }
  }

  /// Upload all pending readings (typically called on job completion)
  Future<void> uploadPendingReadings() async {
    if (!_mlDataSharingEnabled) {
      _pendingReadings.clear();
      return;
    }

    if (_pendingReadings.isEmpty) {
      return;
    }

    try {
      // Batch upload for efficiency
      final batch = _firestore.batch();
      
      for (final reading in _pendingReadings) {
        final docRef = _firestore.collection('ml_hvac_readings').doc(reading.id);
        batch.set(docRef, reading.toFirestore());
      }
      
      await batch.commit();
      
      print('✅ Uploaded ${_pendingReadings.length} ML readings to Firebase');
      _pendingReadings.clear();
    } catch (e) {
      print('Error uploading batch ML readings: $e');
      // Don't throw - ML data upload failures shouldn't block user workflow
    }
  }

  /// Get pending readings count
  int get pendingReadingsCount => _pendingReadings.length;

  /// Clear pending readings without uploading (e.g., if job is cancelled)
  void clearPendingReadings() {
    _pendingReadings.clear();
  }

  /// Record a "before" reading (before adjustments)
  HvacReading recordBeforeReading({
    String? jobId,
    required JobType systemType,
    required Refrigerant refrigerant,
    String? equipmentInfo,
    bool? isFixedOrifice,
    double? suctionPressure,
    double? dischargePressure,
    double? suctionLineTemp,
    double? liquidLineTemp,
    double? supplyAirTemp,
    double? returnAirTemp,
    double? ambientTemp,
    double? superheat,
    double? subcool,
  }) {
    return captureReading(
      jobId: jobId,
      systemType: systemType,
      refrigerant: refrigerant,
      equipmentInfo: equipmentInfo,
      isFixedOrifice: isFixedOrifice,
      suctionPressure: suctionPressure,
      dischargePressure: dischargePressure,
      suctionLineTemp: suctionLineTemp,
      liquidLineTemp: liquidLineTemp,
      supplyAirTemp: supplyAirTemp,
      returnAirTemp: returnAirTemp,
      ambientTemp: ambientTemp,
      superheat: superheat,
      subcool: subcool,
      outcome: ReadingOutcome.unknown,
      technicianNotes: 'Before adjustments',
    );
  }

  /// Record an "after" reading (after adjustments)
  HvacReading recordAfterReading({
    String? jobId,
    required JobType systemType,
    required Refrigerant refrigerant,
    String? equipmentInfo,
    bool? isFixedOrifice,
    double? suctionPressure,
    double? dischargePressure,
    double? suctionLineTemp,
    double? liquidLineTemp,
    double? supplyAirTemp,
    double? returnAirTemp,
    double? ambientTemp,
    double? superheat,
    double? subcool,
    List<String>? adjustmentsMade,
    ReadingOutcome outcome = ReadingOutcome.adjusted,
  }) {
    return captureReading(
      jobId: jobId,
      systemType: systemType,
      refrigerant: refrigerant,
      equipmentInfo: equipmentInfo,
      isFixedOrifice: isFixedOrifice,
      suctionPressure: suctionPressure,
      dischargePressure: dischargePressure,
      suctionLineTemp: suctionLineTemp,
      liquidLineTemp: liquidLineTemp,
      supplyAirTemp: supplyAirTemp,
      returnAirTemp: returnAirTemp,
      ambientTemp: ambientTemp,
      superheat: superheat,
      subcool: subcool,
      outcome: outcome,
      adjustmentsMade: adjustmentsMade,
      technicianNotes: 'After adjustments',
    );
  }
}
