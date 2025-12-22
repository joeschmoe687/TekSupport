import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/gradient_scaffold.dart';

/// Web UI screen for viewing live device data from connected mobile apps
class LiveDataWebScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const LiveDataWebScreen({super.key, required this.onToggleTheme});

  @override
  State<LiveDataWebScreen> createState() => _LiveDataWebScreenState();
}

class _LiveDataWebScreenState extends State<LiveDataWebScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;
  String? _selectedUserId; // For admin viewing other users
  bool _isAdmin = false;
  StreamSubscription? _dataSubscription;
  Map<String, Map<String, dynamic>> _deviceReadings = {};
  DateTime? _lastUpdate;
  List<Map<String, String>> _availableUsers = []; // For admin dropdown

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _userId = user.uid;
      _selectedUserId = user.uid; // Default to viewing own data
    });

    // Check if user is admin
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'] as String? ?? 'user';
    setState(() {
      _isAdmin = role == 'admin';
    });

    // If admin, load list of users with live data
    if (_isAdmin) {
      await _loadAvailableUsers();
    }

    _subscribeToLiveData();
  }

  Future<void> _loadAvailableUsers() async {
    try {
      final liveDataSnapshot = await _firestore.collection('live_device_data').get();
      final users = <Map<String, String>>[];
      
      for (final doc in liveDataSnapshot.docs) {
        final userId = doc.id;
        // Get user info
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        final name = userData?['displayName'] as String? ?? 
                     userData?['name'] as String? ?? 
                     userData?['email'] as String? ?? 
                     'User $userId';
        
        users.add({'id': userId, 'name': name});
      }
      
      if (mounted) {
        setState(() {
          _availableUsers = users;
        });
      }
    } catch (e) {
      debugPrint('[LiveDataWeb] Error loading users: $e');
    }
  }

  void _subscribeToLiveData() {
    final targetUserId = _selectedUserId ?? _userId;
    if (targetUserId == null) return;

    // Cancel existing subscription
    _dataSubscription?.cancel();

    // Subscribe to live device readings
    _dataSubscription = _firestore
        .collection('live_device_data')
        .doc(targetUserId)
        .collection('readings')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      setState(() {
        _deviceReadings.clear();
        for (final doc in snapshot.docs) {
          _deviceReadings[doc.id] = doc.data();
        }
        _lastUpdate = DateTime.now();
      });
    });
  }

  void _changeViewingUser(String? newUserId) {
    if (newUserId == null || newUserId == _selectedUserId) return;
    
    setState(() {
      _selectedUserId = newUserId;
      _deviceReadings.clear();
      _lastUpdate = null;
    });
    
    _subscribeToLiveData();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final DateTime dt = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inSeconds < 60) {
        return '${diff.inSeconds}s ago';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else {
        return '${diff.inHours}h ago';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStatusColor(dynamic timestamp) {
    if (timestamp == null) return Colors.grey;
    try {
      final DateTime dt = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inSeconds < 5) {
        return AppColors.success;
      } else if (diff.inSeconds < 30) {
        return AppColors.warning;
      } else {
        return AppColors.error;
      }
    } catch (e) {
      return Colors.grey;
    }
  }

  String _formatDeviceType(String? type) {
    if (type == null) return 'Unknown';
    // Convert camelCase to Title Case
    final words = type.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    ).trim();
    return words[0].toUpperCase() + words.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Live Device Monitor',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (_isAdmin) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.primaryPurple),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_lastUpdate != null)
              Text(
                'Updated ${_formatTimestamp(Timestamp.fromDate(_lastUpdate!))}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          // Admin user selector
          if (_isAdmin && _availableUsers.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedUserId,
                  icon: Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
                  dropdownColor: AppColors.surfaceDark,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  items: [
                    // Current user option
                    DropdownMenuItem(
                      value: _userId,
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 16, color: AppColors.primaryCyan),
                          const SizedBox(width: 8),
                          const Text('My Devices'),
                        ],
                      ),
                    ),
                    // Divider
                    const DropdownMenuItem(
                      enabled: false,
                      value: null,
                      child: Divider(),
                    ),
                    // Other users
                    ..._availableUsers
                        .where((user) => user['id'] != _userId)
                        .map((user) => DropdownMenuItem(
                              value: user['id'],
                              child: Text(user['name'] ?? 'Unknown'),
                            ))
                        .toList(),
                  ],
                  onChanged: _changeViewingUser,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_isAdmin && _selectedUserId != _userId) {
                _loadAvailableUsers();
              }
              _subscribeToLiveData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing data...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: _userId == null
          ? const Center(
              child: Text('Please sign in to view live data'),
            )
          : _deviceReadings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bluetooth_searching,
                        size: 80,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No active devices',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Connect devices in the mobile app to see live data here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildDeviceGrid(),
    );
  }

  Widget _buildDeviceGrid() {
    final sortedDevices = _deviceReadings.entries.toList()
      ..sort((a, b) {
        final aTime = a.value['timestamp'];
        final bTime = b.value['timestamp'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return (bTime as Timestamp).compareTo(aTime as Timestamp);
      });

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid columns based on width
        int columns = 1;
        if (constraints.maxWidth > 1200) {
          columns = 3;
        } else if (constraints.maxWidth > 800) {
          columns = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: sortedDevices.length,
          itemBuilder: (context, index) {
            final entry = sortedDevices[index];
            return _buildDeviceCard(entry.key, entry.value);
          },
        );
      },
    );
  }

  Widget _buildDeviceCard(String deviceId, Map<String, dynamic> data) {
    final deviceName = data['deviceName'] as String? ?? 'Unknown Device';
    final value = data['value'] as num? ?? 0.0;
    final unit = data['unit'] as String? ?? '';
    final type = data['type'] as String?;
    final timestamp = data['timestamp'];
    final batteryLevel = data['batteryLevel'] as int?;
    final statusColor = _getStatusColor(timestamp);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatDeviceType(type),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (batteryLevel != null)
                _buildBatteryIndicator(batteryLevel),
            ],
          ),

          const SizedBox(height: 16),

          // Value Display
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryCyan,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              if (_isAdmin)
                Text(
                  deviceId.substring(0, 8),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryIndicator(int level) {
    IconData icon;
    Color color;

    if (level > 80) {
      icon = Icons.battery_full;
      color = AppColors.success;
    } else if (level > 50) {
      icon = Icons.battery_6_bar;
      color = AppColors.success;
    } else if (level > 20) {
      icon = Icons.battery_3_bar;
      color = AppColors.warning;
    } else {
      icon = Icons.battery_1_bar;
      color = AppColors.error;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 4),
        Text(
          '$level%',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
