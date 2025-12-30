import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';
import '../services/ble_sniff_upload_service.dart';
import '../services/hci_log_capture_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Settings screen for BLE Sniffer preferences
class BleSnifferSettingsScreen extends StatefulWidget {
  const BleSnifferSettingsScreen({super.key});

  @override
  State<BleSnifferSettingsScreen> createState() =>
      _BleSnifferSettingsScreenState();
}

class _BleSnifferSettingsScreenState extends State<BleSnifferSettingsScreen> {
  final BleSniffUploadService _uploadService = BleSniffUploadService();
  final HciLogCaptureService _hciService = HciLogCaptureService();

  bool _autoUploadEnabled = true;
  bool _uploadAllMode = false;
  bool _loading = true;

  // HCI capture state
  bool? _hciEnabled;
  HciLogData? _currentLog;
  bool _capturing = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkHciStatus();
  }

  Future<void> _loadSettings() async {
    await _uploadService.loadSettings();
    if (!mounted) return;
    setState(() {
      _autoUploadEnabled = _uploadService.autoUploadEnabled;
      _uploadAllMode = _uploadService.uploadAllMode;
      _loading = false;
    });
  }

  Future<void> _checkHciStatus() async {
    try {
      final enabled = await _hciService.isHciLoggingEnabled();
      if (!mounted) return;
      setState(() {
        _hciEnabled = enabled;
      });
    } catch (e) {
      debugPrint('Error checking HCI status: $e');
      if (!mounted) return;
      setState(() {
        _hciEnabled = false;
      });
    }
  }

  Future<void> _captureHciLog() async {
    setState(() {
      _capturing = true;
      _currentLog = null;
    });

    try {
      final logPath = await _hciService.captureHciLog();
      if (logPath == null) {
        throw Exception('Failed to capture HCI log');
      }

      final logData = await _hciService.parseHciLog(logPath);

      if (!mounted) return;
      setState(() {
        _currentLog = logData;
        _capturing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Captured ${logData?.devices.length ?? 0} devices, ${logData?.packets.length ?? 0} packets',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Error capturing HCI log: $e');
      if (!mounted) return;
      setState(() {
        _capturing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture HCI log: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _uploadHciLog() async {
    if (_currentLog == null) return;

    setState(() {
      _uploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _hciService.uploadToFirebase(_currentLog!, user.uid);

      if (!mounted) return;
      setState(() {
        _uploading = false;
        _currentLog = null; // Clear after successful upload
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('HCI log uploaded successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Error uploading HCI log: $e');
      if (!mounted) return;
      setState(() {
        _uploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _toggleAutoUpload(bool value) async {
    try {
      await _uploadService.setAutoUploadEnabled(value);
      setState(() {
        _autoUploadEnabled = value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Auto-upload enabled - New logs will sync automatically'
                  : 'Auto-upload disabled - Manual sync required',
            ),
            backgroundColor: value ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      // Revert UI state on error
      setState(() {
        _autoUploadEnabled = !value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save setting: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleUploadMode(bool value) async {
    try {
      await _uploadService.setUploadAllMode(value);
      setState(() {
        _uploadAllMode = value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Upload ALL logs mode enabled'
                  : 'Upload NEW logs only mode enabled',
            ),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (e) {
      // Revert UI state on error
      setState(() {
        _uploadAllMode = !value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save setting: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'BLE Sniffer Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryCyan),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // HCI Capture section
                Card(
                  color: AppColors.surfaceDark,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.bluetooth_searching,
                              color: AppColors.accentBlue,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'HCI Log Capture',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _hciEnabled == true
                                    ? AppColors.success.withOpacity(0.2)
                                    : AppColors.error.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _hciEnabled == null
                                    ? 'Checking...'
                                    : _hciEnabled!
                                        ? 'Enabled'
                                        : 'Disabled',
                                style: TextStyle(
                                  color: _hciEnabled == true
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Capture system-level Bluetooth HCI logs for detailed protocol analysis',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Capture button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _hciEnabled == true &&
                                    !_capturing &&
                                    !_uploading
                                ? _captureHciLog
                                : null,
                            icon: _capturing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.download),
                            label: Text(_capturing
                                ? 'Capturing...'
                                : 'Capture HCI Log'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),

                        // Device preview
                        if (_currentLog != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryCyan.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.devices,
                                      color: AppColors.primaryCyan,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Captured Data',
                                      style: TextStyle(
                                        color: AppColors.primaryCyan,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.bluetooth,
                                  '${_currentLog!.devices.length} devices detected',
                                ),
                                _buildInfoRow(
                                  Icons.insert_chart,
                                  '${_currentLog!.packets.length} packets captured',
                                ),
                                _buildInfoRow(
                                  Icons.access_time,
                                  _currentLog!.capturedAt.toString(),
                                ),

                                // Device list
                                if (_currentLog!.devices.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Divider(color: AppColors.textMuted),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Devices:',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...(_currentLog!.devices
                                      .take(5)
                                      .map(
                                        (device) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryCyan,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  device.name.isEmpty
                                                      ? device.address
                                                      : '${device.name} (${device.address})',
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList()),
                                  if (_currentLog!.devices.length > 5)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '+ ${_currentLog!.devices.length - 5} more',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),

                          // Upload button
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: !_uploading && _currentLog != null
                                  ? _uploadHciLog
                                  : null,
                              icon: _uploading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload),
                              label: Text(_uploading
                                  ? 'Uploading...'
                                  : 'Upload to Firebase'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],

                        // Warning if disabled
                        if (_hciEnabled == false) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.warning.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'HCI logging is disabled in Developer Options. Enable it to capture logs.',
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Auto-upload toggle
                Card(
                  color: AppColors.surfaceDark,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.cloud_upload,
                              color: AppColors.primaryCyan,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Auto-Upload to Firebase',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Switch(
                              value: _autoUploadEnabled,
                              onChanged: _toggleAutoUpload,
                              activeColor: AppColors.primaryCyan,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _autoUploadEnabled
                              ? 'BLE sniff logs will automatically sync to Firebase after each scan'
                              : 'BLE sniff logs will only sync when manually triggered',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Upload mode selector
                Card(
                  color: AppColors.surfaceDark,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.filter_list,
                              color: AppColors.primaryPurple,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Upload Mode',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Switch(
                              value: _uploadAllMode,
                              onChanged: _toggleUploadMode,
                              activeColor: AppColors.primaryPurple,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _uploadAllMode
                              ? 'Upload ALL logs (including previously synced)'
                              : 'Upload NEW logs only (skip previously synced)',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: _uploadAllMode
                                    ? AppColors.warning
                                    : AppColors.success,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _uploadAllMode
                                      ? 'This mode will re-upload all logs, including duplicates. Useful for initial sync or after data loss.'
                                      : 'Recommended mode. Only uploads new data, preventing duplicates and saving bandwidth.',
                                  style: TextStyle(
                                    color: _uploadAllMode
                                        ? AppColors.warning
                                        : AppColors.success,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Info section
                Card(
                  color: AppColors.surfaceDark.withOpacity(0.7),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: AppColors.accentBlue,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'How It Works',
                              style: TextStyle(
                                color: AppColors.accentBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.check_circle_outline,
                            'Logs are saved locally first'),
                        _buildInfoRow(Icons.cloud_done,
                            'Auto-upload syncs to Firebase in background'),
                        _buildInfoRow(Icons.verified_outlined,
                            'Uploaded logs are marked to prevent duplicates'),
                        _buildInfoRow(Icons.sync,
                            'Manual sync available from main screen'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
