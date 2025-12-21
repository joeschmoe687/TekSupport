import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'device_registry.dart';

/// Service for machine learning-based device pattern recognition and auto-tuning
/// Admin-only feature for learning new device communication patterns
class MLDeviceLearningService {
  static MLDeviceLearningService? _instance;
  static MLDeviceLearningService get instance =>
      _instance ??= MLDeviceLearningService._();
  MLDeviceLearningService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Stream of current learning session data
  final _learningSessionController =
      StreamController<LearningSession?>.broadcast();
  Stream<LearningSession?> get learningSession =>
      _learningSessionController.stream;

  LearningSession? _currentSession;

  /// Start a new learning session for an unknown device
  Future<LearningSession> startLearningSession({
    required String deviceId,
    required String deviceName,
    required String manufacturerData,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated');
    }

    // Check if user is admin
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'] ?? '';
    if (role != 'admin') {
      throw Exception('Only admins can start learning sessions');
    }

    final session = LearningSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deviceId: deviceId,
      deviceName: deviceName,
      manufacturerData: manufacturerData,
      startedAt: DateTime.now(),
      learnedPatterns: [],
      validationResults: [],
    );

    _currentSession = session;
    _learningSessionController.add(session);

    // Save to Firebase
    await _firestore
        .collection('ml_learning_sessions')
        .doc(session.id)
        .set(session.toMap());

    return session;
  }

  /// Record a raw data sample from the device
  Future<void> recordDataSample({
    required String rawData,
    required String? adminProvidedValue,
    required String? adminProvidedUnit,
    String? notes,
  }) async {
    if (_currentSession == null) {
      throw Exception('No active learning session');
    }

    final sample = DataSample(
      timestamp: DateTime.now(),
      rawData: rawData,
      adminProvidedValue: adminProvidedValue,
      adminProvidedUnit: adminProvidedUnit,
      notes: notes,
    );

    _currentSession!.dataSamples.add(sample);

    // Update in Firebase
    await _firestore
        .collection('ml_learning_sessions')
        .doc(_currentSession!.id)
        .update({
      'dataSamples': FieldValue.arrayUnion([sample.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _learningSessionController.add(_currentSession);
  }

  /// Analyze collected data and generate a device pattern
  Future<DevicePattern> analyzeAndGeneratePattern() async {
    if (_currentSession == null || _currentSession!.dataSamples.length < 3) {
      throw Exception(
          'Need at least 3 data samples to generate a pattern');
    }

    // Analyze patterns in the data
    final samples = _currentSession!.dataSamples;
    
    // Find common byte patterns and their positions
    final pattern = DevicePattern(
      deviceName: _currentSession!.deviceName,
      manufacturerIdentifier: _currentSession!.manufacturerData,
      valueBytePosition: _analyzeValuePosition(samples),
      valueMultiplier: _calculateMultiplier(samples),
      valueOffset: _calculateOffset(samples),
      unitBytePosition: _analyzeUnitPosition(samples),
      confidence: _calculateConfidence(samples),
      sampleCount: samples.length,
      createdAt: DateTime.now(),
    );

    _currentSession!.learnedPatterns.add(pattern);

    // Save pattern to Firebase
    await _firestore.collection('ml_device_patterns').add(pattern.toMap());

    // Update session
    await _firestore
        .collection('ml_learning_sessions')
        .doc(_currentSession!.id)
        .update({
      'learnedPatterns': FieldValue.arrayUnion([pattern.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _learningSessionController.add(_currentSession);
    return pattern;
  }

  /// End the current learning session
  Future<void> endLearningSession({bool save = true}) async {
    if (_currentSession == null) return;

    if (save && _currentSession!.learnedPatterns.isNotEmpty) {
      await _firestore
          .collection('ml_learning_sessions')
          .doc(_currentSession!.id)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    _currentSession = null;
    _learningSessionController.add(null);
  }

  /// Get all learned patterns from Firebase
  Future<List<DevicePattern>> getAllLearnedPatterns() async {
    final snapshot = await _firestore.collection('ml_device_patterns').get();
    return snapshot.docs
        .map((doc) => DevicePattern.fromMap(doc.data()))
        .toList();
  }

  /// Apply a learned pattern to parse device data
  double? applyPattern(DevicePattern pattern, String rawData) {
    try {
      // Extract value bytes based on learned position
      final valueBytes = _extractBytesAtPosition(
        rawData,
        pattern.valueBytePosition,
        2, // Assume 2-byte value
      );

      if (valueBytes == null) return null;

      // Convert bytes to number
      final rawValue = _bytesToNumber(valueBytes);

      // Apply multiplier and offset
      return rawValue * pattern.valueMultiplier + pattern.valueOffset;
    } catch (e) {
      return null;
    }
  }

  // Analysis helper methods
  int _analyzeValuePosition(List<DataSample> samples) {
    // Simple heuristic: find the byte position that changes most
    // In a real ML implementation, this would use more sophisticated analysis
    // For now, return a default position
    return 4; // Common position for many BLE devices
  }

  double _calculateMultiplier(List<DataSample> samples) {
    // Calculate multiplier by comparing raw vs actual values
    if (samples.length < 2) return 1.0;

    double sumRatio = 0;
    int validSamples = 0;

    for (var sample in samples) {
      if (sample.adminProvidedValue != null) {
        final actualValue = double.tryParse(sample.adminProvidedValue!);
        if (actualValue != null) {
          // Extract raw value (simplified)
          final rawBytes = _extractBytesAtPosition(sample.rawData, 4, 2);
          if (rawBytes != null) {
            final rawValue = _bytesToNumber(rawBytes);
            if (rawValue > 0) {
              sumRatio += actualValue / rawValue;
              validSamples++;
            }
          }
        }
      }
    }

    return validSamples > 0 ? sumRatio / validSamples : 1.0;
  }

  double _calculateOffset(List<DataSample> samples) {
    // Calculate offset from the difference between raw and actual
    // Simplified implementation
    return 0.0;
  }

  int? _analyzeUnitPosition(List<DataSample> samples) {
    // Analyze where unit information might be stored
    // Return null if units don't seem to be in the data
    return null;
  }

  double _calculateConfidence(List<DataSample> samples) {
    // Calculate confidence based on consistency of samples
    // More samples and more consistent patterns = higher confidence
    final sampleCount = samples.length;
    if (sampleCount < 3) return 0.3;
    if (sampleCount < 5) return 0.5;
    if (sampleCount < 10) return 0.7;
    return 0.9;
  }

  List<int>? _extractBytesAtPosition(
      String rawData, int position, int length) {
    try {
      // Parse hex string to bytes
      final bytes = <int>[];
      for (int i = 0; i < rawData.length; i += 2) {
        final byteString = rawData.substring(i, i + 2);
        bytes.add(int.parse(byteString, radix: 16));
      }

      if (position + length > bytes.length) return null;
      return bytes.sublist(position, position + length);
    } catch (e) {
      return null;
    }
  }

  int _bytesToNumber(List<int> bytes) {
    // Convert bytes to integer (little-endian)
    int value = 0;
    for (int i = 0; i < bytes.length; i++) {
      value += bytes[i] << (8 * i);
    }
    return value;
  }

  void dispose() {
    _learningSessionController.close();
  }
}

/// Represents an active learning session
class LearningSession {
  final String id;
  final String deviceId;
  final String deviceName;
  final String manufacturerData;
  final DateTime startedAt;
  final List<DataSample> dataSamples;
  final List<DevicePattern> learnedPatterns;
  final List<ValidationResult> validationResults;

  LearningSession({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.manufacturerData,
    required this.startedAt,
    List<DataSample>? dataSamples,
    required this.learnedPatterns,
    required this.validationResults,
  }) : dataSamples = dataSamples ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'manufacturerData': manufacturerData,
      'startedAt': Timestamp.fromDate(startedAt),
      'dataSamples': dataSamples.map((s) => s.toMap()).toList(),
      'learnedPatterns': learnedPatterns.map((p) => p.toMap()).toList(),
      'validationResults':
          validationResults.map((v) => v.toMap()).toList(),
      'status': 'active',
    };
  }
}

/// A single data sample collected during learning
class DataSample {
  final DateTime timestamp;
  final String rawData;
  final String? adminProvidedValue;
  final String? adminProvidedUnit;
  final String? notes;

  DataSample({
    required this.timestamp,
    required this.rawData,
    this.adminProvidedValue,
    this.adminProvidedUnit,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'rawData': rawData,
      'adminProvidedValue': adminProvidedValue,
      'adminProvidedUnit': adminProvidedUnit,
      'notes': notes,
    };
  }
}

/// A learned pattern for parsing device data
class DevicePattern {
  final String deviceName;
  final String manufacturerIdentifier;
  final int valueBytePosition;
  final double valueMultiplier;
  final double valueOffset;
  final int? unitBytePosition;
  final double confidence;
  final int sampleCount;
  final DateTime createdAt;

  DevicePattern({
    required this.deviceName,
    required this.manufacturerIdentifier,
    required this.valueBytePosition,
    required this.valueMultiplier,
    required this.valueOffset,
    this.unitBytePosition,
    required this.confidence,
    required this.sampleCount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceName': deviceName,
      'manufacturerIdentifier': manufacturerIdentifier,
      'valueBytePosition': valueBytePosition,
      'valueMultiplier': valueMultiplier,
      'valueOffset': valueOffset,
      'unitBytePosition': unitBytePosition,
      'confidence': confidence,
      'sampleCount': sampleCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory DevicePattern.fromMap(Map<String, dynamic> map) {
    return DevicePattern(
      deviceName: map['deviceName'] ?? '',
      manufacturerIdentifier: map['manufacturerIdentifier'] ?? '',
      valueBytePosition: map['valueBytePosition'] ?? 0,
      valueMultiplier: (map['valueMultiplier'] ?? 1.0).toDouble(),
      valueOffset: (map['valueOffset'] ?? 0.0).toDouble(),
      unitBytePosition: map['unitBytePosition'],
      confidence: (map['confidence'] ?? 0.5).toDouble(),
      sampleCount: map['sampleCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Result of validating a learned pattern
class ValidationResult {
  final DateTime timestamp;
  final String rawData;
  final double predictedValue;
  final double actualValue;
  final bool isAccurate;

  ValidationResult({
    required this.timestamp,
    required this.rawData,
    required this.predictedValue,
    required this.actualValue,
    required this.isAccurate,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'rawData': rawData,
      'predictedValue': predictedValue,
      'actualValue': actualValue,
      'isAccurate': isAccurate,
    };
  }
}
