import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/gradient_scaffold.dart';
import '../services/tekmate_chat_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final String roomId;
  final bool isTekMateChat;

  const ChatDetailScreen({
    super.key,
    required this.roomId,
    this.isTekMateChat = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  final TekMateChatService _tekMateService = TekMateChatService();

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      // For TekMate chats, send directly to TekMate service
      if (widget.isTekMateChat) {
        await _sendTekMateMessage(text);
        _controller.clear();
        return;
      }

      // Regular support chat flow
      // Add message to room
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'role': 'user',
        'from': 'customer',
        'text': text,
        'messageText': text,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent', // Message status: sent, delivered, read
        'readBy': [], // Array of user IDs who have read this message
      });

      // Update room
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.roomId)
          .update({
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadByTech': FieldValue.increment(1),
      });

      _controller.clear();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    }
  }

  Future<void> _sendTekMateMessage(String text) async {
    try {
      // Add user message to Firestore
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'role': 'user',
        'from': 'admin',
        'text': text,
        'messageText': text,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Get TekMate response
      final responseData = await _tekMateService.getResponse(
        text,
        platform: 'app',
      );

      if (responseData == null) {
        throw Exception('Failed to get TekMate response');
      }

      if (mounted) {
        // Add TekMate response to Firestore
        await FirebaseFirestore.instance
            .collection('supportRooms')
            .doc(widget.roomId)
            .collection('messages')
            .add({
          'role': 'assistant',
          'from': 'tekmate',
          'text': responseData.response,
          'messageText': responseData.response,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error with TekMate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TekMate error: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      // Upload to Firebase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(widget.roomId)
          .child(fileName);

      final uploadTask = await ref.putFile(File(image.path));
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Add image message to Firestore
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'role': 'user',
        'from': 'customer',
        'text': '📷 Image',
        'messageText': '📷 Image',
        'imageUrl': downloadUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update room
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.roomId)
          .update({
        'lastMessage': '📷 Image',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isUploading = false);
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: AppColors.primaryCyan,
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: AppColors.primaryCyan,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Support Chat Session'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('supportRooms')
                    .doc(widget.roomId)
                    .collection('messages')
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> msgSnapshot) {
                  if (msgSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryCyan,
                      ),
                    );
                  }

                  var messages = msgSnapshot.data?.docs ?? [];

                  // Sort messages manually by createdAt (new) or timestamp (old)
                  // This handles both old messages (with timestamp) and new ones (with createdAt)
                  messages.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    final aTime = aData['createdAt'] ??
                        aData['timestamp'] ??
                        Timestamp.now();
                    final bTime = bData['createdAt'] ??
                        bData['timestamp'] ??
                        Timestamp.now();

                    return (aTime as Timestamp).compareTo(bTime as Timestamp);
                  });

                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages in this conversation yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final data = msg.data() as Map<String, dynamic>;
                      final messageText =
                          data['messageText'] ?? data['text'] ?? '(no content)';
                      final role = data['role'] ?? data['from'] ?? 'user';
                      final isCustomer = role == 'user' || role == 'customer';
                      final imageUrl = data['imageUrl'] as String?;
                      final isCompletionRequest =
                          data['isCompletionRequest'] == true;

                      // Skip empty messages without images
                      if (messageText.trim().isEmpty &&
                          imageUrl == null &&
                          !isCompletionRequest) {
                        return const SizedBox.shrink();
                      }

                      // Special handling for completion request messages
                      if (isCompletionRequest) {
                        return _buildCompletionRequestCard(msg.id, data);
                      }

                      return Align(
                        alignment: isCustomer
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 12,
                          ),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCustomer
                                ? AppColors.primaryPurple.withOpacity(0.3)
                                : AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(8),
                            border: isCustomer
                                ? null
                                : Border.all(color: AppColors.border),
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (imageUrl != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: GestureDetector(
                                    onTap: () =>
                                        _showFullImage(context, imageUrl),
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      placeholder: (context, url) => Container(
                                        height: 150,
                                        color: AppColors.surfaceLight,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.primaryCyan,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        height: 150,
                                        color: AppColors.surfaceLight,
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                if (messageText != '📷 Image' &&
                                    messageText.isNotEmpty)
                                  const SizedBox(height: 8),
                              ],
                              if (messageText != '📷 Image' || imageUrl == null)
                                Text(
                                  messageText,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              // Read receipt indicator for customer messages
                              if (isCustomer) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getReceiptIcon(data),
                                      size: 14,
                                      color: _getReceiptColor(data),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getReceiptText(data),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _getReceiptColor(data),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Upload indicator
            if (_isUploading)
              Container(
                padding: const EdgeInsets.all(8),
                color: AppColors.surfaceDark,
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.primaryCyan,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Uploading image...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.attach_file,
                        color: AppColors.primaryCyan,
                      ),
                      onPressed: _isUploading ? null : _showImageSourceDialog,
                      tooltip: 'Attach photo',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                placeholder: (context, url) => CircularProgressIndicator(
                  color: AppColors.primaryCyan,
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionRequestCard(
    String messageId,
    Map<String, dynamic> data,
  ) {
    final customerResponse = data['customerResponse'] as String?;
    final hasResponded = customerResponse != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasResponded
              ? (customerResponse == 'accepted' ? Colors.green : Colors.orange)
              : AppColors.primaryCyan,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            hasResponded
                ? (customerResponse == 'accepted'
                    ? Icons.check_circle
                    : Icons.help_outline)
                : Icons.help_outline,
            color: hasResponded
                ? (customerResponse == 'accepted'
                    ? Colors.green
                    : Colors.orange)
                : AppColors.primaryCyan,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            hasResponded
                ? (customerResponse == 'accepted'
                    ? 'You confirmed this issue as resolved'
                    : 'You indicated you need more help')
                : 'Is your issue resolved?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            hasResponded
                ? (customerResponse == 'accepted'
                    ? 'Thank you for your feedback!'
                    : 'Our team will continue to help you.')
                : 'Please let us know if we\'ve answered your question.',
            style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (!hasResponded) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _respondToCompletion(messageId, 'accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Yes, Resolved'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _respondToCompletion(messageId, 'declined'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Need More Help'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _respondToCompletion(String messageId, String response) async {
    try {
      final roomRef = FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.roomId);

      // Update the message with customer response
      await roomRef.collection('messages').doc(messageId).update({
        'customerResponse': response,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // If accepted, mark the room as complete
      if (response == 'accepted') {
        await roomRef.update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'customerConfirmed': true,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session marked as complete. Thank you!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Notify admin that customer needs more help
        await roomRef.update({
          'completionRequested': false,
          'customerDeclinedCompletion': true,
          'declinedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Our team will continue to help you.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper methods for read receipts
  IconData _getReceiptIcon(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? 'sent';
    final readBy = data['readBy'] as List<dynamic>? ?? [];

    if (readBy.isNotEmpty) {
      return Icons.done_all; // Read (double check)
    } else if (status == 'delivered') {
      return Icons.done_all; // Delivered (double check, grey)
    } else {
      return Icons.done; // Sent (single check)
    }
  }

  Color _getReceiptColor(Map<String, dynamic> data) {
    final readBy = data['readBy'] as List<dynamic>? ?? [];

    if (readBy.isNotEmpty) {
      return AppColors.primaryCyan; // Read - cyan
    } else {
      return AppColors.textMuted; // Sent/Delivered - grey
    }
  }

  String _getReceiptText(Map<String, dynamic> data) {
    final readBy = data['readBy'] as List<dynamic>? ?? [];

    if (readBy.isNotEmpty) {
      return 'Read';
    } else {
      final status = data['status']?.toString() ?? 'sent';
      return status == 'delivered' ? 'Delivered' : 'Sent';
    }
  }
}
