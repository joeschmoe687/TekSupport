import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/gradient_scaffold.dart';

class TechReplyScreen extends StatefulWidget {
  final String messageId;
  final String customerPhone;
  final VoidCallback onToggleTheme;

  const TechReplyScreen({
    super.key,
    required this.messageId,
    required this.customerPhone,
    required this.onToggleTheme,
  });

  @override
  State<TechReplyScreen> createState() => _TechReplyScreenState();
}

class _TechReplyScreenState extends State<TechReplyScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late Stream<QuerySnapshot> _messagesStream;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _setupStream();
    _claimMessage();
  }

  void _setupStream() {
    // Don't use orderBy to avoid index requirements - sort in Dart instead
    _messagesStream =
        FirebaseFirestore.instance
            .collection('supportRooms')
            .doc(widget.messageId)
            .collection('messages')
            .snapshots();
  }

  Future<void> _claimMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.messageId)
          .update({
            'status': 'claimed',
            'claimedBy': user.uid,
            'hasLiveTech': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error claiming message: $e');
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final file = File(pickedFile.path);
      final filename =
          '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
      final storageRef = FirebaseStorage.instance.ref().child(
        'chat_images/${widget.messageId}/$filename',
      );

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Send message with image
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.messageId)
          .collection('messages')
          .add({
            'role': 'support',
            'senderType': 'tech',
            'from': 'tech',
            'techId': user.uid,
            'messageText': '📷 Image',
            'text': '📷 Image',
            'imageUrl': downloadUrl,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.messageId)
          .update({
            'lastMessage': '📷 Image',
            'status': 'claimed',
            'claimedBy': user.uid,
            'hasLiveTech': true,
            'unreadByCustomer': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
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

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(color: Colors.black87),
                ),
                InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder:
                        (context, url) => Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryCyan,
                          ),
                        ),
                    errorWidget:
                        (context, url, error) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.messageId)
          .collection('messages')
          .add({
            'role': 'support',
            'senderType': 'tech',
            'from': 'tech',
            'techId': user.uid,
            'messageText': text,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Update room last message and status
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.messageId)
          .update({
            'lastMessage': text,
            'status': 'claimed',
            'claimedBy': user.uid,
            'hasLiveTech': true,
            'unreadByCustomer': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _replyController.clear();
    } catch (e) {
      debugPrint('Error sending reply: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending reply: $e')));
      }
    }
  }

  Future<void> _markSessionComplete() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            title: const Text(
              'Mark Session Complete?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'The customer will need to pay for a new session to start another chat.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                child: const Text(
                  'Complete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Update room status to completed
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.messageId)
          .update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'completedBy': user.email ?? 'tech',
            'completedByUid': user.uid,
          });

      // Add system message
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.messageId)
          .collection('messages')
          .add({
            'text':
                '✅ This support session has been marked as complete. Thank you for using TekNeck Support!',
            'role': 'system',
            'isSystemMessage': true,
            'timestamp': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Session marked as complete'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context); // Go back to chat list
      }
    } catch (e) {
      debugPrint('Error marking session complete: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Chat with ${widget.customerPhone}'),
        actions: [
          TextButton.icon(
            onPressed: _markSessionComplete,
            icon: Icon(Icons.check_circle, color: AppColors.success),
            label: Text(
              'Complete',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryCyan,
                      ),
                    ),
                  );
                }

                // Sort messages manually to handle both old (timestamp) and new (createdAt) fields
                var messages =
                    (snapshot.data?.docs ?? []).toList()..sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime =
                          aData['createdAt'] ??
                          aData['timestamp'] ??
                          Timestamp.now();
                      final bTime =
                          bData['createdAt'] ??
                          bData['timestamp'] ??
                          Timestamp.now();
                      return (aTime as Timestamp).compareTo(bTime as Timestamp);
                    });

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final data = msg.data() as Map<String, dynamic>;
                    final isTech =
                        data['senderType'] == 'tech' || data['from'] == 'tech';
                    final isAI =
                        data['senderType'] == 'ai' || data['from'] == 'ai';
                    final messageText =
                        data['messageText'] ?? data['text'] ?? '';
                    final imageUrl = data['imageUrl'] as String?;

                    return Align(
                      alignment:
                          isTech ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              isAI
                                  ? AppColors.primaryPurple.withOpacity(0.3)
                                  : isTech
                                  ? AppColors.primaryCyan.withOpacity(0.2)
                                  : AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isAI)
                              Text(
                                'AI Assistant',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primaryCyan,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (imageUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: GestureDetector(
                                  onTap:
                                      () => _showFullImage(context, imageUrl),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    placeholder:
                                        (context, url) => Container(
                                          height: 150,
                                          color: AppColors.surfaceLight,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: AppColors.primaryCyan,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                    errorWidget:
                                        (context, url, error) => Container(
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
                                style: const TextStyle(color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(color: AppColors.surfaceDark),
            child: SafeArea(
              child: Row(
                children: [
                  // Attachment button
                  _isUploading
                      ? Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryCyan,
                        ),
                      )
                      : IconButton(
                        icon: Icon(
                          Icons.attach_file,
                          color: AppColors.primaryCyan,
                        ),
                        onPressed: () => _showImageSourceDialog(context),
                        tooltip: 'Attach image',
                      ),
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type your reply...',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
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
                      onPressed: _sendReply,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
