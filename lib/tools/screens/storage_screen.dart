import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/gradient_scaffold.dart';
import '../services/device_storage_service.dart';

/// Storage screen for viewing saved device data, ML patterns, and profiles.
/// Accessible from Settings.
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen>
    with SingleTickerProviderStateMixin {
  final DeviceStorageService _storage = DeviceStorageService();
  late TabController _tabController;

  StorageStats? _stats;
  List<SavedDevice> _devices = [];
  List<ConnectionEvent> _history = [];
  List<LearnedPattern> _patterns = [];
  List<CustomDeviceProfile> _profiles = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await _storage.init();

    final stats = await _storage.getStorageStats();
    final devices = await _storage.getSavedDevices();
    final history = await _storage.getConnectionHistory();
    final patterns = await _storage.getLearnedPatterns();
    final profiles = await _storage.getDeviceProfiles();

    if (mounted) {
      setState(() {
        _stats = stats;
        _devices = devices;
        _history = history.reversed.toList(); // Most recent first
        _patterns = patterns;
        _profiles = profiles;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Clear All Data?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will remove all saved devices, connection history, learned patterns, and custom profiles. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storage.clearAllData();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('All data cleared'),
              backgroundColor: AppColors.success),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Storage',
            style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryCyan),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            color: AppColors.surfaceDark,
            onSelected: (value) {
              if (value == 'clear') _clearAllData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever,
                        color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Clear All Data',
                        style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryCyan,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primaryCyan,
          tabs: const [
            Tab(icon: Icon(Icons.devices), text: 'Devices'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.psychology), text: 'ML'),
            Tab(icon: Icon(Icons.description), text: 'Profiles'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryCyan))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDevicesTab(),
                _buildHistoryTab(),
                _buildMlTab(),
                _buildProfilesTab(),
              ],
            ),
    );
  }

  Widget _buildStatsHeader() {
    if (_stats == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
              'Devices', _stats!.deviceCount.toString(), Icons.bluetooth),
          _buildStatItem(
              'Events', _stats!.historyCount.toString(), Icons.history),
          _buildStatItem(
              'Patterns', _stats!.patternCount.toString(), Icons.psychology),
          _buildStatItem('Size', _stats!.formattedSize, Icons.storage),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryCyan, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDevicesTab() {
    if (_devices.isEmpty) {
      return _buildEmptyState(
          'No saved devices', 'Connect to a device to save it here');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return _buildDeviceItem(device);
      },
    );
  }

  Widget _buildDeviceItem(SavedDevice device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  device.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              if (device.autoReconnect)
                const Icon(Icons.autorenew, color: AppColors.success, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          _buildDeviceDetail('ID', device.remoteId),
          _buildDeviceDetail('Manufacturer', device.manufacturer),
          _buildDeviceDetail('Type', device.deviceType),
          _buildDeviceDetail('Unit', device.unit.isEmpty ? 'N/A' : device.unit),
          _buildDeviceDetail('First Paired', _formatDate(device.firstPaired)),
          _buildDeviceDetail('Last Seen', _formatDate(device.lastSeen)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _copyToClipboard(device.remoteId),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy ID'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  await _storage.removeDevice(device.remoteId);
                  await _loadData();
                },
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return _buildEmptyState('No connection history',
          'Events will appear as you connect to devices');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final event = _history[index];
        return _buildHistoryItem(event);
      },
    );
  }

  Widget _buildHistoryItem(ConnectionEvent event) {
    final icon = _getEventIcon(event.eventType);
    final color = _getEventColor(event.eventType);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.deviceName,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  '${event.eventType}${event.reason != null ? ' • ${event.reason}' : ''}',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _formatTime(event.timestamp),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'connected':
        return Icons.bluetooth_connected;
      case 'disconnected':
        return Icons.bluetooth_disabled;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.circle;
    }
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'connected':
        return AppColors.success;
      case 'disconnected':
        return AppColors.warning;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  Widget _buildMlTab() {
    if (_patterns.isEmpty) {
      return _buildEmptyState(
        'No learned patterns yet',
        'Use the BLE Sniffer to analyze device data patterns.\n\n'
            'ML patterns help the app automatically interpret sensor data from new devices.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _patterns.length,
      itemBuilder: (context, index) {
        final pattern = _patterns[index];
        return _buildPatternItem(pattern);
      },
    );
  }

  Widget _buildPatternItem(LearnedPattern pattern) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology,
                  color: AppColors.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pattern.deviceName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      _getConfidenceColor(pattern.confidence).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${pattern.confidence}%',
                  style: TextStyle(
                    color: _getConfidenceColor(pattern.confidence),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPatternDetail('Data Type', pattern.dataType),
          _buildPatternDetail('Parse Method', pattern.parseMethod),
          _buildPatternDetail('Unit', pattern.unit),
          _buildPatternDetail('Characteristic', pattern.characteristicUuid),
          _buildPatternDetail('Learned', _formatDate(pattern.learnedAt)),
          if (pattern.sampleValues.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Sample values: ${pattern.sampleValues.take(5).join(", ")}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPatternDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return AppColors.success;
    if (confidence >= 50) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildProfilesTab() {
    if (_profiles.isEmpty) {
      return _buildEmptyState(
        'No custom profiles',
        'Use "Save Profile" in the BLE Sniffer to save device configurations for production use.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _profiles.length,
      itemBuilder: (context, index) {
        final profile = _profiles[index];
        return _buildProfileItem(profile);
      },
    );
  }

  Widget _buildProfileItem(CustomDeviceProfile profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description,
                  color: AppColors.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  profile.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProfileDetail('Manufacturer', profile.manufacturer),
          _buildProfileDetail('Type', profile.type),
          _buildProfileDetail('Service UUID', profile.serviceUuid),
          _buildProfileDetail('Char UUID', profile.characteristicUuid),
          _buildProfileDetail('Parse Method', profile.parseMethod),
          _buildProfileDetail('Unit', profile.unit),
          _buildProfileDetail('Created', _formatDate(profile.createdAt)),
          if (profile.notes != null && profile.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: ${profile.notes}',
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _exportProfile(profile),
                icon: const Icon(Icons.code, size: 16),
                label: const Text('Export Code'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryCyan),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  await _storage.deleteDeviceProfile(profile.id);
                  await _loadData();
                },
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _exportProfile(CustomDeviceProfile profile) {
    final code = '''
// ${profile.name} Profile
// Generated: ${_formatDate(profile.createdAt)}

const ${_toCamelCase(profile.name)}Profile = HvacDeviceProfile(
  name: '${profile.name}',
  manufacturer: HvacManufacturer.${profile.manufacturer},
  type: HvacDeviceType.${profile.type},
  namePatterns: ['${profile.name}'],
  serviceUuid: '${profile.serviceUuid}',
  characteristicUuid: '${profile.characteristicUuid}',
  unit: '${profile.unit}',
  parser: (data) {
    // Parse method: ${profile.parseMethod}
    if (data.length < 2) return 0.0;
    final raw = ByteData.sublistView(Uint8List.fromList(data)).getInt16(0, Endian.little);
    return raw / 10.0;
  },
);
''';

    _copyToClipboard(code);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Profile code copied to clipboard'),
          backgroundColor: AppColors.success),
    );
  }

  String _toCamelCase(String input) {
    final words =
        input.split(RegExp(r'[\s_-]+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    final first = words.first.toLowerCase();
    final rest = words
        .skip(1)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join('');
    return first + rest;
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: AppColors.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    return '${date.month}/${date.day} $hour:$min $ampm';
  }
}
