import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../services/call_recording_service.dart';
import '../services/call_recording_upload_service.dart';
import '../widgets/gradient_scaffold.dart';

/// UI screen showing user's local call history and recordings
/// Allows users to view calls, upload recordings, delete old records
class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  late CallRecordingService _callService;
  late CallRecordingUploadService _uploadService;
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<CallLogEntry> callLogs = [];
  bool isLoading = true;
  int storageUsagePercent = 0;

  @override
  void initState() {
    super.initState();
    _callService = CallRecordingService();
    _uploadService = CallRecordingUploadService();
    _loadCallLogs();
  }

  /// Load call logs from Firestore
  Future<void> _loadCallLogs() async {
    try {
      setState(() => isLoading = true);

      final snapshot = await FirebaseFirestore.instance
          .collection('callLogs')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      final logs = snapshot.docs.map((doc) {
        final data = doc.data();
        return CallLogEntry(
          id: doc.id,
          userId: data['userId'] as String,
          phoneNumber: data['phoneNumber'] as String,
          callType: data['callType'] as String,
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          duration: data['duration'] as int,
          recordingPath: data['recordingPath'] as String?,
          recordingUrl: data['recordingUrl'] as String?,
          uploadedAt: data['uploadedAt'] as bool?,
          userConsent: data['userConsent'] as bool,
        );
      }).toList();

      // Calculate storage usage
      final sizeBytes = await _callService.getLocalRecordingsSize();
      final quotaBytes = 500 * 1024 * 1024; // 500 MB
      final percent = ((sizeBytes / quotaBytes) * 100).toInt();

      setState(() {
        callLogs = logs;
        storageUsagePercent = percent;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading call logs: $e');
      setState(() => isLoading = false);
    }
  }

  /// Format duration from seconds to readable format
  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// Format timestamp
  String _formatTimestamp(DateTime dt) {
    return DateFormat('MMM dd, yyyy hh:mm a').format(dt);
  }

  /// Get call type display text and icon
  (String, IconData, Color) _getCallTypeInfo(String callType) {
    switch (callType) {
      case 'incoming':
        return ('Incoming', Icons.call_received, Colors.green);
      case 'outgoing':
        return ('Outgoing', Icons.call_made, Colors.blue);
      case 'missed':
        return ('Missed', Icons.call_missed, Colors.red);
      default:
        return ('Call', Icons.call, Colors.grey);
    }
  }

  /// Upload single recording to admin folder
  Future<void> _uploadRecording(CallLogEntry log) async {
    if (log.recordingPath == null || log.recordingPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recording file found')),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading recording...')),
      );

      final uploadUrl = await _uploadService.uploadRecording(
        userId: userId,
        callLogId: log.id,
        recordingPath: log.recordingPath!,
        phoneNumber: log.phoneNumber,
        callType: log.callType,
      );

      // Update Firestore with upload URL
      await FirebaseFirestore.instance
          .collection('callLogs')
          .doc(log.id)
          .update({
        'recordingUrl': uploadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCallLogs(); // Refresh
      }
    } catch (e) {
      print('Error uploading recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  /// Delete call log and recording
  Future<void> _deleteCallLog(CallLogEntry log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Call Record?'),
        content: Text(
          'This will permanently delete the call record and recording for ${log.phoneNumber}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete local file
      if (log.recordingPath != null) {
        final file = File(log.recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Delete Firestore record
      await FirebaseFirestore.instance
          .collection('callLogs')
          .doc(log.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call record deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCallLogs();
      }
    } catch (e) {
      print('Error deleting call log: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  /// Clean up old recordings if storage quota exceeded
  Future<void> _cleanupOldRecordings() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cleaning up old recordings...')),
      );

      await _callService.cleanupOldRecordings(quotaMB: 500);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Old recordings cleaned up'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCallLogs();
      }
    } catch (e) {
      print('Error cleaning up: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _loadCallLogs,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  // Storage usage indicator
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Local Storage Usage',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '$storageUsagePercent%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: storageUsagePercent > 80
                                    ? Colors.orange
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: storageUsagePercent / 100,
                            minHeight: 8,
                            backgroundColor: Colors.grey.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              storageUsagePercent > 80
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                          ),
                        ),
                        if (storageUsagePercent > 80)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ElevatedButton.icon(
                              onPressed: _cleanupOldRecordings,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Clean Up Old Recordings'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Call logs list
                  if (callLogs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(Icons.call, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No call records yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: callLogs.length,
                      itemBuilder: (ctx, idx) {
                        final log = callLogs[idx];
                        final (typeLabel, typeIcon, typeColor) =
                            _getCallTypeInfo(log.callType);
                        final hasRecording = log.recordingPath != null &&
                            log.recordingPath!.isNotEmpty;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: Icon(typeIcon, color: typeColor),
                            title: Text(
                              log.phoneNumber,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  typeLabel,
                                  style: TextStyle(color: typeColor),
                                ),
                                Text(
                                  _formatTimestamp(log.timestamp),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _formatDuration(log.duration),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                if (hasRecording)
                                  Text(
                                    log.uploadedAt == true
                                        ? '✓ Uploaded'
                                        : '⚠ Local',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: log.uploadedAt == true
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              _showCallDetailSheet(log);
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
      ),
    );
  }

  /// Show detailed view for call with upload/delete options
  void _showCallDetailSheet(CallLogEntry log) {
    final (typeLabel, typeIcon, typeColor) = _getCallTypeInfo(log.callType);
    final hasRecording =
        log.recordingPath != null && log.recordingPath!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(typeIcon, color: typeColor, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.phoneNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          typeLabel,
                          style: TextStyle(color: typeColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Call Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Date: ${_formatTimestamp(log.timestamp)}'),
              Text('Duration: ${_formatDuration(log.duration)}'),
              if (hasRecording)
                Text(
                    'Recording: ${log.uploadedAt == true ? "✓ Uploaded" : "⚠ Local"}'),
              const SizedBox(height: 16),
              if (hasRecording && log.uploadedAt != true)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _uploadRecording(log);
                    },
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload Recording'),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteCallLog(log);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Delete Record',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
