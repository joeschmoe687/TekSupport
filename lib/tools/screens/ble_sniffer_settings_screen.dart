import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';
import '../services/ble_sniff_upload_service.dart';

/// Settings screen for BLE Sniffer preferences
class BleSnifferSettingsScreen extends StatefulWidget {
  const BleSnifferSettingsScreen({super.key});

  @override
  State<BleSnifferSettingsScreen> createState() => _BleSnifferSettingsScreenState();
}

class _BleSnifferSettingsScreenState extends State<BleSnifferSettingsScreen> {
  final BleSniffUploadService _uploadService = BleSniffUploadService();
  bool _autoUploadEnabled = true;
  bool _uploadAllMode = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
                          style: const TextStyle(
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
                          style: const TextStyle(
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
              style: const TextStyle(
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
