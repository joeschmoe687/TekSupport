import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tech_reply_screen.dart';
import '../widgets/gradient_scaffold.dart';

class TechInboxScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const TechInboxScreen({super.key, required this.onToggleTheme});

  @override
  State<TechInboxScreen> createState() => _TechInboxScreenState();
}

class _TechInboxScreenState extends State<TechInboxScreen> {
  late Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .where('status', whereIn: ['open', 'assigned'])
        .where('hasLiveTech', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Support Inbox'),
        backgroundColor: Colors.transparent,
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _messagesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primaryCyan),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No messages yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final messages = snapshot.data!.docs;

          return ListView.separated(
            itemCount: messages.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final msg = messages[index];
              final data = msg.data() as Map<String, dynamic>;
              final customerName = data['customerName'] ?? 'Unknown';
              final supportType = data['supportType'] ?? 'text';
              final timestamp = data['createdAt'] as Timestamp?;
              final claimedBy = data['claimedBy'];

              return ListTile(
                title: Text(customerName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support Type: ${supportType.toUpperCase()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Status: ${claimedBy != null ? "Claimed by tech" : "Unclaimed"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: claimedBy != null ? Colors.orange : Colors.green,
                      ),
                    ),
                    if (timestamp != null)
                      Text(
                        timestamp.toDate().toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                trailing: claimedBy == null
                    ? ElevatedButton(
                        onPressed: () => _claimSession(msg.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryCyan,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Claim'),
                      )
                    : const Icon(Icons.check_circle, color: Colors.green),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TechReplyScreen(
                        messageId: msg.id,
                        customerPhone: customerName,
                        onToggleTheme: widget.onToggleTheme,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Helper: Claim a support session by setting claimedBy and hasLiveTech
  Future<void> _claimSession(String chatId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'claimedBy': user.uid,
        'hasLiveTech': true,
        'status': 'assigned',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session claimed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error claiming session: $e')),
        );
      }
    }
  }
}
