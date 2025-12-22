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

    _messagesStream =
        FirebaseFirestore.instance
            .collection('incomingSMS')
            .where('status', whereIn: ['new', 'assigned'])
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
              final customerPhone = data['customerPhone'] ?? 'Unknown';
              final messageText = data['messageText'] ?? '';
              final status = data['status'] ?? 'new';
              final timestamp = data['createdAt'] as Timestamp?;

              return ListTile(
                title: Text('From: $customerPhone'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      messageText.length > 50
                          ? '${messageText.substring(0, 50)}...'
                          : messageText,
                    ),
                    Text(
                      'Status: $status',
                      style: TextStyle(fontSize: 12),
                    ),
                    if (timestamp != null)
                      Text(
                        timestamp.toDate().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => TechReplyScreen(
                            messageId: msg.id,
                            customerPhone: customerPhone,
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
}
