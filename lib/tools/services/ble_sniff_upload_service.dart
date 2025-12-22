import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for managing automated BLE sniff log uploads to Firebase.
/// Tracks which sessions have been uploaded and handles auto-sync.
class BleSniffUploadService {
  static final BleSniffUploadService _instance = BleSniffUploadService._internal();
  factory BleSniffUploadService() => _instance;
  BleSniffUploadService._internal();

  static const String _prefKeyAutoUpload = 'ble_sniff_auto_upload';
  static const String _prefKeyUploadAll = 'ble_sniff_upload_all_mode';
  
  bool _autoUploadEnabled = true; // Default to auto-upload
  bool _uploadAllMode = false; // Default to only upload new logs
  
  /// Get current auto-upload setting
  bool get autoUploadEnabled => _autoUploadEnabled;
  
  /// Get current upload mode (true = all logs, false = only new/unsynced)
  bool get uploadAllMode => _uploadAllMode;
  
  /// Initialize settings from SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoUploadEnabled = prefs.getBool(_prefKeyAutoUpload) ?? true;
      _uploadAllMode = prefs.getBool(_prefKeyUploadAll) ?? false;
      debugPrint('[BleSniffUpload] Settings loaded - AutoUpload: $_autoUploadEnabled, UploadAll: $_uploadAllMode');
    } catch (e) {
      debugPrint('[BleSniffUpload] Failed to load settings: $e');
    }
  }
  
  /// Set auto-upload enabled/disabled
  Future<void> setAutoUploadEnabled(bool enabled) async {
    final previousValue = _autoUploadEnabled;
    _autoUploadEnabled = enabled;

    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setBool(_prefKeyAutoUpload, enabled);

      if (!success) {
        _autoUploadEnabled = previousValue;
        debugPrint('[BleSniffUpload] Failed to persist auto-upload setting (setBool returned false)');
        throw Exception('Failed to save auto-upload setting');
      }

      debugPrint('[BleSniffUpload] Auto-upload ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _autoUploadEnabled = previousValue;
      debugPrint('[BleSniffUpload] Error saving auto-upload setting: $e');
      rethrow;
    }
  }
  
  /// Set upload mode (true = all logs, false = only new)
  Future<void> setUploadAllMode(bool uploadAll) async {
    final previousValue = _uploadAllMode;
    _uploadAllMode = uploadAll;

    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setBool(_prefKeyUploadAll, uploadAll);

      if (!success) {
        _uploadAllMode = previousValue;
        debugPrint('[BleSniffUpload] Failed to persist upload mode setting (setBool returned false)');
        throw Exception('Failed to save upload mode setting');
      }

      debugPrint('[BleSniffUpload] Upload mode: ${uploadAll ? 'ALL logs' : 'NEW logs only'}');
    } catch (e) {
      _uploadAllMode = previousValue;
      debugPrint('[BleSniffUpload] Error saving upload mode setting: $e');
      rethrow;
    }
  }
  
  /// Check if a session has been uploaded
  bool isSessionUploaded(Map<String, dynamic> sessionData) {
    return sessionData['uploaded'] == true || sessionData['syncedAt'] != null;
  }
  
  /// Mark a session as uploaded in Hive storage
  Future<void> markSessionUploaded(Box sniffBox, String sessionId, Map<String, dynamic> sessionData) async {
    try {
      final updatedData = {
        ...sessionData,
        'uploaded': true,
        'uploadedAt': DateTime.now().toIso8601String(),
      };
      await sniffBox.put(sessionId, jsonEncode(updatedData));
      debugPrint('[BleSniffUpload] Marked session $sessionId as uploaded');
    } catch (e) {
      debugPrint('[BleSniffUpload] Failed to mark session uploaded: $e');
    }
  }
  
  /// Upload a single session to Firebase
  Future<bool> uploadSession(Map<String, dynamic> sessionData) async {
    try {
      final docId = 'sniff_${sessionData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}';
      
      await FirebaseFirestore.instance
          .collection('ble_sniff_logs')
          .doc(docId)
          .set(
        {
          ...sessionData,
          'syncedAt': FieldValue.serverTimestamp(),
          'autoUploaded': true,
        },
        SetOptions(merge: true),
      );
      
      debugPrint('[BleSniffUpload] Uploaded session: $docId');
      return true;
    } catch (e) {
      debugPrint('[BleSniffUpload] Failed to upload session: $e');
      return false;
    }
  }
  
  /// Auto-upload all unsynced sessions from Hive storage
  /// Returns the number of sessions uploaded
  Future<int> uploadUnsyncedSessions(Box sniffBox) async {
    if (!_autoUploadEnabled) {
      debugPrint('[BleSniffUpload] Auto-upload disabled, skipping');
      return 0;
    }
    
    int uploadCount = 0;
    
    try {
      for (final key in sniffBox.keys) {
        final data = sniffBox.get(key);
        if (data == null) continue;
        
        try {
          final sessionData = Map<String, dynamic>.from(jsonDecode(data));
          
          // Check if session should be uploaded
          final shouldUpload = _uploadAllMode || !isSessionUploaded(sessionData);
          
          if (shouldUpload) {
            final success = await uploadSession(sessionData);
            if (success) {
              await markSessionUploaded(sniffBox, key, sessionData);
              uploadCount++;
            }
          }
        } catch (e) {
          debugPrint('[BleSniffUpload] Failed to process session $key: $e');
        }
      }
      
      debugPrint('[BleSniffUpload] Uploaded $uploadCount sessions');
    } catch (e) {
      debugPrint('[BleSniffUpload] Failed to upload unsynced sessions: $e');
    }
    
    return uploadCount;
  }
  
  /// Auto-upload a single session after save (if auto-upload is enabled)
  Future<bool> autoUploadSessionIfEnabled(Box sniffBox, String sessionId, Map<String, dynamic> sessionData) async {
    if (!_autoUploadEnabled) {
      return false;
    }
    
    // Only upload if it's new (not already uploaded) or if upload-all mode is enabled
    if (_uploadAllMode || !isSessionUploaded(sessionData)) {
      final success = await uploadSession(sessionData);
      if (success) {
        await markSessionUploaded(sniffBox, sessionId, sessionData);
      }
      return success;
    }
    
    return false;
  }
}
