import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_chat_detail_screen.dart';
import '../widgets/gradient_scaffold.dart';

class AdminChatSessionsScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const AdminChatSessionsScreen({super.key, required this.onToggleTheme});

  @override
  State<AdminChatSessionsScreen> createState() =>
      _AdminChatSessionsScreenState();
}

class _AdminChatSessionsScreenState extends State<AdminChatSessionsScreen> {
  StreamSubscription<QuerySnapshot>? _roomsSub;
  final List<QueryDocumentSnapshot> _allDocs = [];
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _roomsSub?.cancel();
    _allDocs.clear();
    _roomsSub = FirebaseFirestore.instance
        .collection('supportRooms')
        .limit(200)
        .snapshots()
        .listen((snap) {
          debugPrint('supportRooms docs: ${snap.docs.length}');
          _mergeDocs(snap.docs);
        });
  }

  void _mergeDocs(List<QueryDocumentSnapshot> docs) {
    final ids = docs.map((d) => d.id).toSet();
    _allDocs.removeWhere((d) => ids.contains(d.id));
    _allDocs.addAll(docs);
    if (mounted) setState(() {});
  }

  void _onFilterChanged(String value) {
    setState(() {
      _filter = value;
    });
  }

  @override
  void dispose() {
    _roomsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Support Sessions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.brightness_6,
              color: AppColors.textSecondary,
            ),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            Container(
              color: AppColors.surfaceDark.withOpacity(0.8),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Filter:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', 'all', AppColors.primaryCyan),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Unclaimed',
                            'queue',
                            AppColors.warning,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Active',
                            'claimed',
                            AppColors.success,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_allDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Support Sessions',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'New chats will appear here',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final docs =
                      _allDocs.where((d) {
                        final m = d.data() as Map<String, dynamic>;
                        final s = (m['status'] ?? '').toString().toLowerCase();
                        final hasLiveTech = (m['hasLiveTech'] ?? false) == true;
                        final inQueue =
                            s == 'unclaimed' ||
                            s == 'new' ||
                            s == 'open' ||
                            s == 'pending' ||
                            s.isEmpty;
                        if (_filter == 'all') {
                          return true;
                        } else if (_filter == 'queue') {
                          return inQueue;
                        } else if (_filter == 'claimed') {
                          return s == 'claimed' ||
                              s == 'active' ||
                              s == 'assigned' ||
                              s == 'inprogress' ||
                              s == 'engaged' ||
                              hasLiveTech;
                        }
                        return true;
                      }).toList();

                  docs.sort((a, b) {
                    final ma = a.data() as Map<String, dynamic>;
                    final mb = b.data() as Map<String, dynamic>;
                    final ta = ma['updatedAt'] ?? ma['createdAt'];
                    final tb = mb['updatedAt'] ?? mb['createdAt'];
                    final da =
                        ta is Timestamp
                            ? ta.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                    final db =
                        tb is Timestamp
                            ? tb.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                    return db.compareTo(da);
                  });

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final map = doc.data() as Map<String, dynamic>;
                      return _buildChatCard(
                        doc.id,
                        map,
                        context,
                        AppColors.primaryCyan,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => _onFilterChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildChatCard(
    String roomId,
    Map<String, dynamic> data,
    BuildContext context,
    Color primaryAccent,
  ) {
    final userName =
        data['customerName'] ??
        data['customerEmail'] ??
        data['userEmail'] ??
        (data['userData']?['name']) ??
        data['displayName'] ??
        data['userId'] ??
        data['phone'] ??
        'Unknown';
    final lastMessage = data['lastMessage'] ?? '';
    final status = (data['status'] ?? 'unclaimed').toString().toLowerCase();
    final hasLiveTech = data['hasLiveTech'] == true;
    final isFreeTrialUser = data['accountType'] == 'free_trial';
    final ts = data['updatedAt'] ?? data['createdAt'];

    // Get problem description from intake data
    final intakeData = data['intakeData'] as Map<String, dynamic>?;
    final problem = intakeData?['problemDescription'] ?? '';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (status == 'claimed' ||
        status == 'active' ||
        status == 'assigned' ||
        hasLiveTech) {
      statusColor = Colors.green;
      statusIcon = Icons.chat;
      statusText = 'Active';
    } else if (status == 'unclaimed' ||
        status == 'new' ||
        status == 'pending' ||
        status == 'open') {
      statusColor = Colors.orange;
      statusIcon = Icons.notification_important;
      statusText = 'Pending';
    } else if (status == 'completed') {
      statusColor = Colors.blue;
      statusIcon = Icons.check_circle;
      statusText = 'Completed';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
      statusText = status;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => AdminChatDetailScreen(
                      roomId: roomId,
                      onToggleTheme: widget.onToggleTheme,
                    ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  userName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isFreeTrialUser)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.orange),
                                  ),
                                  child: const Text(
                                    'Free Trial',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusText.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (problem.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            problem,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (lastMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    lastMessage.length > 80
                        ? '${lastMessage.substring(0, 80)}...'
                        : lastMessage,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (ts != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formatTimestamp(ts),
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => AdminChatDetailScreen(
                                    roomId: roomId,
                                    onToggleTheme: widget.onToggleTheme,
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat, size: 16),
                        label: const Text('Open Chat'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryAccent,
                          side: BorderSide(color: primaryAccent),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _markComplete(roomId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Icon(Icons.check, size: 16),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _deleteChat(roomId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Icon(Icons.delete, size: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    try {
      final dt = ts is Timestamp ? ts.toDate() : DateTime.parse(ts.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) {
        return 'Just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return '${dt.month}/${dt.day}/${dt.year}';
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _markComplete(String roomId) async {
    try {
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(roomId)
          .update({
            'status': 'completed',
            'hasLiveTech': false,
            'completedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error marking complete: $e');
    }
  }

  Future<void> _deleteChat(String roomId) async {
    try {
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(roomId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting: $e');
    }
  }
}
