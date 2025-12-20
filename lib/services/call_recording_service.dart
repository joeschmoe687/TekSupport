import 'package:record/record.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'call_recording_geo_service.dart';

// Platform channel for native call state monitoring
const platform = MethodChannel('com.tekneck.hvac_support/call_recording');

/// Models for call log data
class CallLogEntry {
  final String id;
  final String userId;
  final String phoneNumber;
  final String callType; // 'incoming', 'outgoing', 'missed'
  final DateTime timestamp;
  final int duration; // seconds
  final String? recordingPath; // local file path
  final String? recordingUrl; // uploaded URL
  final bool? uploadedAt;
  final bool userConsent;

  CallLogEntry({
    required this.id,
    required this.userId,
    required this.phoneNumber,
    required this.callType,
    required this.timestamp,
    required this.duration,
    this.recordingPath,
    this.recordingUrl,
    this.uploadedAt,
    required this.userConsent,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'phoneNumber': phoneNumber,
      'callType': callType,
      'timestamp': Timestamp.fromDate(timestamp),
      'duration': duration,
      'recordingPath': recordingPath,
      'recordingUrl': recordingUrl,
      'uploadedAt': uploadedAt,
      'userConsent': userConsent,
    };
  }
}

/// Service to monitor, record, and log phone calls
/// Requires GDPR-compliant consent from user before recording
class CallRecordingService {
  static const platform = MethodChannel('com.tekneck.hvac/calls');
  static const audioChannel = MethodChannel('com.tekneck.hvac/audio');

  late final AudioRecorder _audioRecorder;
  String? _currentRecordingPath;

  String? _currentCallNumber;
  DateTime? _callStartTime;
  bool _isRecording = false;
  bool _recordingEnabled = false;
  String? _userId;

  CallRecordingService() {
    _audioRecorder = AudioRecorder();
    _setupCallStateListener();
  }

  /// Setup native call state listener via platform channel
  void _setupCallStateListener() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onCallStateChanged':
          final state = call.arguments['state'] as String;
          final phoneNumber = call.arguments['phoneNumber'] as String?;
          await _handleCallStateFromNative(state, phoneNumber);
          break;
      }
    });
  }

  /// Initialize call recording service
  /// Must be called after user consents during signup
  Future<void> initialize(String userId, bool recordingConsent) async {
    _userId = userId;
    _recordingEnabled = recordingConsent;

    // Additional check: verify location allows recording
    if (_recordingEnabled) {
      final allowedByGeo =
          await CallRecordingGeoService.isCallRecordingAllowed();
      _recordingEnabled = allowedByGeo;

      if (!allowedByGeo) {
        print(
            'Call recording disabled: User location does not allow recording');
      }
    }

    // Initialize native call monitoring via platform channel
    try {
      await platform.invokeMethod('initializeCallMonitoring', {
        'userId': userId,
        'enabled': _recordingEnabled,
      });
    } catch (e) {
      print('Error initializing native call monitoring: $e');
    }
  }

  /// Handle call state changes from native platform
  Future<void> _handleCallStateFromNative(
      String state, String? phoneNumber) async {
    try {
      print('Call state from native: $state, phone: $phoneNumber');

      switch (state) {
        case 'RINGING':
          _currentCallNumber = phoneNumber;
          await _handleIncomingCall();
          break;
        case 'OFFHOOK':
          if (!_isRecording && _recordingEnabled) {
            _callStartTime = DateTime.now();
            await _startCallRecording();
          }
          break;
        case 'IDLE':
          await _handleCallEnded('idle');
          break;
      }
    } catch (e) {
      print('Error handling call state: $e');
    }
  }

  /// Handle incoming call - play voice notice before recording starts
  Future<void> _handleIncomingCall() async {
    try {
      if (_recordingEnabled) {
        // Play voice prompt: "This call may be recorded for quality assurance"
        await _playVoiceNotice();
      }

      // Get incoming phone number via platform channel
      final phoneNumber =
          await platform.invokeMethod<String>('getIncomingPhoneNumber');
      _currentCallNumber = phoneNumber ?? 'Unknown';
      _callStartTime = DateTime.now();
    } catch (e) {
      print('Error handling incoming call: $e');
    }
  }

  /// Play voice notice before recording begins (compliance requirement)
  Future<void> _playVoiceNotice() async {
    try {
      await audioChannel.invokeMethod('playVoiceNotice', {
        'message':
            'This call may be recorded for quality assurance. Data is stored securely.',
      });
      print('Voice notice played');
    } catch (e) {
      print('Error playing voice notice: $e');
    }
  }

  /// Start recording the call
  Future<void> _startCallRecording() async {
    try {
      if (!_recordingEnabled || _isRecording) return;

      // Request permission
      if (!await _audioRecorder.hasPermission()) {
        print('Audio recording permission denied');
        return;
      }

      // Generate filename: call_TIMESTAMP_PHONENUMBER.m4a
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedPhone =
          _currentCallNumber?.replaceAll(RegExp(r'[^0-9]'), '') ?? 'unknown';
      final fileName = 'call_${timestamp}_$sanitizedPhone.m4a';

      // Get app's cache directory for local storage
      final appDir = await getApplicationCacheDirectory();
      final recordingPath = '${appDir.path}/recordings/$fileName';

      // Create recordings directory if doesn't exist
      final recordingsDir = Directory('${appDir.path}/recordings');
      if (!recordingsDir.existsSync()) {
        recordingsDir.createSync(recursive: true);
      }

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
        ),
        path: recordingPath,
      );

      _currentRecordingPath = recordingPath;

      _isRecording = true;
      print('Call recording started: $recordingPath');
    } catch (e) {
      print('Error starting call recording: $e');
      _isRecording = false;
    }
  }

  /// Handle call ended - stop recording and log to Firestore
  Future<void> _handleCallEnded(String callType) async {
    try {
      _isRecording = false;

      final endTime = DateTime.now();
      final duration = _callStartTime != null
          ? endTime.difference(_callStartTime!).inSeconds
          : 0;

      String? recordingPath;

      // Stop recording if active
      if (_currentRecordingPath != null) {
        final finalPath = await _audioRecorder.stop();
        recordingPath = finalPath ?? _currentRecordingPath;
        _currentRecordingPath = null;
        print('Call recording stopped: $recordingPath');
      }

      // Log to Firestore
      if (_userId != null && _currentCallNumber != null) {
        await _logCallToFirestore(
          phoneNumber: _currentCallNumber!,
          callType: callType,
          duration: duration,
          recordingPath: recordingPath,
        );
      }

      // Reset state
      _currentCallNumber = null;
      _callStartTime = null;
    } catch (e) {
      print('Error handling call ended: $e');
    }
  }

  /// Log call metadata to Firestore
  Future<void> _logCallToFirestore({
    required String phoneNumber,
    required String callType,
    required int duration,
    String? recordingPath,
  }) async {
    try {
      final callLog = CallLogEntry(
        id: FirebaseFirestore.instance.collection('callLogs').doc().id,
        userId: _userId!,
        phoneNumber: phoneNumber,
        callType: callType,
        timestamp: DateTime.now(),
        duration: duration,
        recordingPath: recordingPath,
        userConsent: _recordingEnabled,
      );

      await FirebaseFirestore.instance
          .collection('callLogs')
          .doc(callLog.id)
          .set(callLog.toFirestore());

      print('Call logged to Firestore: ${callLog.id}');
    } catch (e) {
      print('Error logging call to Firestore: $e');
    }
  }

  /// Get all local call recordings
  Future<List<File>> getLocalRecordings() async {
    try {
      final appDir = await getApplicationCacheDirectory();
      final recordingsDir = Directory('${appDir.path}/recordings');

      if (!recordingsDir.existsSync()) {
        return [];
      }

      final files = recordingsDir.listSync().whereType<File>().toList();

      return files;
    } catch (e) {
      print('Error getting local recordings: $e');
      return [];
    }
  }

  /// Get total local recording storage size
  Future<int> getLocalRecordingsSize() async {
    try {
      final recordings = await getLocalRecordings();
      int totalSize = 0;

      for (var file in recordings) {
        totalSize += await file.length();
      }

      return totalSize;
    } catch (e) {
      print('Error getting recordings size: $e');
      return 0;
    }
  }

  /// Check if local storage quota exceeded (500 MB default)
  Future<bool> isStorageQuotaExceeded({int quotaMB = 500}) async {
    final sizeBytes = await getLocalRecordingsSize();
    final quotaBytes = quotaMB * 1024 * 1024;
    return sizeBytes > quotaBytes;
  }

  /// Delete oldest recordings if quota exceeded
  Future<void> cleanupOldRecordings({int quotaMB = 500}) async {
    try {
      if (!await isStorageQuotaExceeded(quotaMB: quotaMB)) {
        return;
      }

      final recordings = await getLocalRecordings();
      recordings.sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified));

      int currentSize = await getLocalRecordingsSize();
      final quotaBytes = quotaMB * 1024 * 1024;

      // Delete oldest files until under quota
      for (var file in recordings) {
        if (currentSize <= quotaBytes) break;

        final fileSize = await file.length();
        await file.delete();
        currentSize -= fileSize;
        print('Deleted old recording: ${file.path}');
      }
    } catch (e) {
      print('Error cleaning up recordings: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_isRecording && _currentRecordingPath != null) {
      await _audioRecorder.stop();
    }
    await _audioRecorder.dispose();

    // Cleanup native call monitoring
    try {
      await platform.invokeMethod('stopCallMonitoring');
    } catch (e) {
      print('Error stopping native call monitoring: $e');
    }
  }
}
