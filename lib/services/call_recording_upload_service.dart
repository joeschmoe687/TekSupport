import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to handle uploading call recordings to Firebase Storage
/// Stores in ADMIN/callRecordings/ directory with organized structure
class CallRecordingUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload recording file to ADMIN/callRecordings/
  /// Returns the download URL
  Future<String> uploadRecording({
    required String userId,
    required String callLogId,
    required String recordingPath,
    required String phoneNumber,
    required String callType,
  }) async {
    try {
      // Verify file exists
      final file = File(recordingPath);
      if (!await file.exists()) {
        throw Exception('Recording file not found: $recordingPath');
      }

      // Generate organized path: ADMIN/callRecordings/YYYY/MM/DD/filename
      final now = DateTime.now();
      final yearMonth =
          '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

      // Sanitize phone number for filename
      final sanitizedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'call_${sanitizedPhone}_${callType}_$timestamp.m4a';

      final uploadPath = 'ADMIN/callRecordings/$yearMonth/$userId/$filename';

      print('Uploading recording to: $uploadPath');

      // Upload file
      final ref = _storage.ref(uploadPath);
      final uploadTask = ref.putFile(file);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for upload to complete
      await uploadTask;

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();

      print('Recording uploaded successfully: $downloadUrl');

      // Log upload event to Firestore for audit trail
      await _logUploadEvent(
        userId: userId,
        callLogId: callLogId,
        phoneNumber: phoneNumber,
        callType: callType,
        uploadPath: uploadPath,
        downloadUrl: downloadUrl,
      );

      return downloadUrl;
    } catch (e) {
      print('Error uploading recording: $e');
      rethrow;
    }
  }

  /// Log upload event to Firestore for compliance audit trail
  Future<void> _logUploadEvent({
    required String userId,
    required String callLogId,
    required String phoneNumber,
    required String callType,
    required String uploadPath,
    required String downloadUrl,
  }) async {
    try {
      await _firestore.collection('uploadAuditLog').add({
        'userId': userId,
        'callLogId': callLogId,
        'phoneNumber': phoneNumber,
        'callType': callType,
        'uploadPath': uploadPath,
        'downloadUrl': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      print('Upload event logged for audit trail');
    } catch (e) {
      print('Error logging upload event: $e');
      // Don't rethrow - upload succeeded even if logging failed
    }
  }

  /// Get all uploaded recordings for a user
  Future<List<Map<String, dynamic>>> getUserUploadedRecordings(
      String userId) async {
    try {
      final snapshot = await _firestore
          .collection('callLogs')
          .where('userId', isEqualTo: userId)
          .where('uploadedAt', isNotEqualTo: null)
          .orderBy('uploadedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting uploaded recordings: $e');
      return [];
    }
  }

  /// Delete recording from Firebase Storage
  /// Used when user requests deletion
  Future<void> deleteRecording(String downloadUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(downloadUrl);
      await ref.delete();
      print('Recording deleted from storage: $downloadUrl');
    } catch (e) {
      print('Error deleting recording: $e');
      rethrow;
    }
  }

  /// Get all recordings in ADMIN/callRecordings/ (admin only)
  /// Returns list of file references with metadata
  Future<List<Map<String, dynamic>>> getAdminCallRecordings({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final ref = _storage.ref('ADMIN/callRecordings/');

      // List all files recursively
      final result = await ref.listAll();

      final recordings = <Map<String, dynamic>>[];

      for (var fileRef in result.items) {
        try {
          final metadata = await fileRef.getMetadata();
          final downloadUrl = await fileRef.getDownloadURL();

          // Filter by date if provided
          final uploadTime = metadata.updated;
          if (fromDate != null && uploadTime!.isBefore(fromDate)) continue;
          if (toDate != null && uploadTime!.isAfter(toDate)) continue;

          recordings.add({
            'path': fileRef.fullPath,
            'name': fileRef.name,
            'size': metadata.size,
            'uploadedAt': uploadTime,
            'downloadUrl': downloadUrl,
          });
        } catch (e) {
          print('Error getting metadata for file: $e');
        }
      }

      // Sort by upload time descending
      recordings.sort((a, b) {
        final timeA = a['uploadedAt'] as DateTime?;
        final timeB = b['uploadedAt'] as DateTime?;
        if (timeA == null || timeB == null) return 0;
        return timeB.compareTo(timeA);
      });

      return recordings;
    } catch (e) {
      print('Error getting admin call recordings: $e');
      return [];
    }
  }

  /// Calculate total storage used by call recordings
  Future<int> getTotalRecordingsSize() async {
    try {
      final recordings = await getAdminCallRecordings();
      int totalSize = 0;

      for (var recording in recordings) {
        totalSize += (recording['size'] as int?) ?? 0;
      }

      return totalSize;
    } catch (e) {
      print('Error calculating recordings size: $e');
      return 0;
    }
  }

  /// Format bytes to human-readable size
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get audit log entries
  Future<List<Map<String, dynamic>>> getUploadAuditLog({
    int limit = 100,
    DateTime? fromDate,
  }) async {
    try {
      var query = _firestore
          .collection('uploadAuditLog')
          .orderBy('uploadedAt', descending: true)
          .limit(limit);

      if (fromDate != null) {
        query = query.where(
          'uploadedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate),
        ) as Query<Map<String, dynamic>>;
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting audit log: $e');
      return [];
    }
  }
}
