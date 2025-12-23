import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/gradient_scaffold.dart';
import 'chat_detail_screen.dart';
import 'support_contact_screen.dart';
import 'payment_screen.dart';

class ChatScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const ChatScreen({super.key, required this.onToggleTheme});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Map<String, double> _pricing = {};
  bool _isBusinessHours = false;

  @override
  void initState() {
    super.initState();
    _isBusinessHours = _checkBusinessHours();
    _loadPricing();
  }

  bool _checkBusinessHours() {
    final now = DateTime.now();
    final cstOffset = Duration(hours: -6); // CST is UTC-6
    final cstTime = now.add(cstOffset);
    final hour = cstTime.hour;
    final weekday = cstTime.weekday; // 1 = Monday, 7 = Sunday
    return hour >= 9 && hour < 17 && weekday >= 1 && weekday <= 5;
  }

  Future<void> _loadPricing() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('pricing')
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _pricing = {
            'bizMessage': (doc.data()?['bizMessage'] ?? 5).toDouble(),
            'bizPhone': (doc.data()?['bizPhone'] ?? 45).toDouble(),
            'bizVideo': (doc.data()?['bizVideo'] ?? 60).toDouble(),
            'twentyFourMessage': (doc.data()?['twentyFourMessage'] ?? 45).toDouble(),
            'twentyFourPhone': (doc.data()?['twentyFourPhone'] ?? 60).toDouble(),
            'twentyFourVideo': (doc.data()?['twentyFourVideo'] ?? 80).toDouble(),
          };
        });
      }
    } catch (error) {
      debugPrint('Error loading pricing: $error');
    }
  }

  double _getPrice(String type) {
    if (_isBusinessHours) {
      return _pricing['biz$type'] ?? 0.0;
    } else {
      return _pricing['twentyFour$type'] ?? 0.0;
    }
  }

  void _showProfileDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user.email}'),
            const SizedBox(height: 8),
            Text('User ID: ${user.uid}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Profile and Support buttons row at top
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.phone, color: AppColors.textPrimary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SupportContactScreen(),
                        ),
                      );
                    },
                    tooltip: 'Support Contact',
                  ),
                  IconButton(
                    icon: Icon(Icons.person, color: AppColors.textPrimary),
                    onPressed: _showProfileDialog,
                    tooltip: 'Profile',
                  ),
                ],
              ),
            ),
            Expanded(
              child: user == null
                  ? const Center(
                      child: Text(
                        'Please log in',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('supportRooms')
                          .where('userId', isEqualTo: user.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryCyan,
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              'No support chats yet. Create one to get started!',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }

                        // Sort manually to avoid needing Firestore index
                        final rooms = snapshot.data!.docs.toList()
                          ..sort((a, b) {
                            final aTime =
                                (a.data() as Map<String, dynamic>)['updatedAt']
                                    as Timestamp?;
                            final bTime =
                                (b.data() as Map<String, dynamic>)['updatedAt']
                                    as Timestamp?;
                            if (aTime == null && bTime == null) return 0;
                            if (aTime == null) return 1;
                            if (bTime == null) return -1;
                            return bTime.compareTo(aTime); // Descending
                          });

                        return ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: rooms.length,
                          itemBuilder: (context, index) {
                            final room = rooms[index];
                            final data = room.data() as Map<String, dynamic>;
                            final status = data['status'] ?? 'pending';
                            final lastMessage =
                                data['lastMessage'] ?? 'No messages yet';
                            final updatedAt = data['updatedAt'] as Timestamp?;
                            final timeAgo = updatedAt != null
                                ? _formatTimeAgo(updatedAt.toDate())
                                : 'just now';

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text(
                                  'Session ${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _statusColor(
                                              status,
                                            ).withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: FutureBuilder<String>(
                                            future: _getStatusText(
                                              status,
                                              data,
                                            ),
                                            builder: (
                                              context,
                                              statusSnapshot,
                                            ) =>
                                                Text(
                                              statusSnapshot.data ??
                                                  (status[0].toUpperCase() +
                                                      status.substring(
                                                        1,
                                                      )),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: _statusColor(
                                                  status,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          timeAgo,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatDetailScreen(
                                        roomId: room.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'chat_screen_fab',
        onPressed: _showSupportOptions,
        backgroundColor: AppColors.primaryCyan,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Get Support', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showSupportOptions() {
    final messagePrice = _getPrice('Message');
    final phonePrice = _getPrice('Phone');
    final videoPrice = _getPrice('Video');
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Choose Support Type',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _isBusinessHours ? '🟢 Business Hours' : '🌙 24HR',
                    style: TextStyle(
                      color: _isBusinessHours ? Colors.green : Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SupportOptionCard(
                icon: Icons.chat_bubble_outline,
                title: 'Text Chat',
                subtitle: '\$${messagePrice.toStringAsFixed(0)}${_isBusinessHours ? '' : ' (24HR)'}',
                description: 'Chat with HVAC techs anytime',
                color: AppColors.primaryCyan,
                onTap: () {
                  Navigator.pop(context);
                  _launchCheckout('text', (messagePrice * 100).toInt(), null);
                },
              ),
              const SizedBox(height: 12),
              _SupportOptionCard(
                icon: Icons.phone_in_talk,
                title: 'Phone Support',
                subtitle: '\$${phonePrice.toStringAsFixed(0)} per session${_isBusinessHours ? '' : ' (24HR)'}',
                description: 'Live phone call with a tech',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _launchCheckout('phone', (phonePrice * 100).toInt(), null);
                },
              ),
              const SizedBox(height: 12),
              _SupportOptionCard(
                icon: Icons.videocam,
                title: 'Video Call',
                subtitle: '\$${videoPrice.toStringAsFixed(0)} per session${_isBusinessHours ? '' : ' (24HR)'}',
                description: 'Face-to-face video support',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  _launchCheckout('video', (videoPrice * 100).toInt(), null);
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Secure payment via Stripe • ${_isBusinessHours ? '9-5 CST Mon-Fri' : 'After hours pricing'}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchCheckout(
    String type,
    int amountCents,
    int? monthlyCents,
  ) async {
    // Navigate to new payment screen instead of external URL
    final String description = _getDescriptionForType(type);

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          supportType: type,
          amountCents: amountCents,
          description: description,
        ),
      ),
    );

    // If payment was successful, show confirmation
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Payment successful! A tech will contact you soon.'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  String _getDescriptionForType(String type) {
    switch (type) {
      case 'text':
        return 'Text Chat Support - Chat with HVAC techs anytime';
      case 'phone':
        return 'Phone Support - Live phone call with a tech';
      case 'video':
        return 'Video Call Support - Face-to-face video support';
      case 'emergency':
        return 'Emergency Support - Priority response for urgent issues';
      default:
        return 'TekNeck Support Service';
    }
  }

  Future<String> _getStatusText(
    String status,
    Map<String, dynamic> roomData,
  ) async {
    final statusLower = status.toLowerCase();

    // For claimed/in progress status, show who claimed it
    if (statusLower == 'claimed' || statusLower == 'in progress') {
      final claimedBy = roomData['claimedBy'] ?? roomData['assignedTo'];
      if (claimedBy != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(claimedBy)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            final name = userData['displayName'] ??
                userData['name'] ??
                userData['email']?.split('@')[0] ??
                'Tech';
            return 'Claimed by $name';
          }
        } catch (e) {
          debugPrint('Error fetching claimed user: $e');
        }
      }
    }

    // Default: capitalize first letter
    return status[0].toUpperCase() + status.substring(1);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${(diff.inDays / 7).floor()}w ago';
    }
  }
}

/// Support option card for the bottom sheet
class _SupportOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _SupportOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(51),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(51),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
