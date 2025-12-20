import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../widgets/gradient_scaffold.dart';

class AdminChatDetailScreen extends StatefulWidget {
  final String roomId;
  final VoidCallback onToggleTheme;

  const AdminChatDetailScreen({
    super.key,
    required this.roomId,
    required this.onToggleTheme,
  });

  @override
  State<AdminChatDetailScreen> createState() => _AdminChatDetailScreenState();
}

class _AdminChatDetailScreenState extends State<AdminChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _roomData;
  Map<String, dynamic>? _userData;
  String? _assignedToName;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadRoomData();
    _claimIfNeeded();
  }

  Future<void> _loadRoomData() async {
    try {
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('supportRooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Chat room not found')));
          Navigator.pop(context);
        }
        return;
      }

      final roomData = roomDoc.data()!;
      _roomData = roomData;

      // Load user data if available
      final userId = roomData['userId'] ?? roomData['customerUID'];
      if (userId != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
        if (userDoc.exists) {
          _userData = userDoc.data();
        }
      }

      // Load assigned tech/admin name
      final assignedTo = roomData['claimedBy'] ?? roomData['assignedTo'];
      if (assignedTo != null) {
        final assignedDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(assignedTo)
                .get();
        if (assignedDoc.exists) {
          final assignedData = assignedDoc.data()!;
          _assignedToName =
              assignedData['displayName'] ??
              assignedData['name'] ??
              assignedData['email'] ??
              'Unknown';
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading room data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _claimIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('supportRooms')
              .doc(widget.roomId)
              .get();

      final data = roomDoc.data();
      if (data == null) return;

      final status = data['status']?.toString().toLowerCase() ?? '';
      final claimedBy = data['claimedBy'];

      // Auto-claim if unclaimed
      if (claimedBy == null &&
          (status == 'unclaimed' ||
              status == 'new' ||
              status == 'open' ||
              status.isEmpty)) {
        await FirebaseFirestore.instance
            .collection('supportRooms')
            .doc(widget.roomId)
            .update({
              'status': 'claimed',
              'claimedBy': user.uid,
              'hasLiveTech': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        _loadRoomData(); // Reload to show assignment
      }
    } catch (e) {
      debugPrint('Error claiming: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Add message to subcollection
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.roomId)
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

      // Update room
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.roomId)
          .update({
            'lastMessage': text,
            'updatedAt': FieldValue.serverTimestamp(),
            'unreadByCustomer': FieldValue.increment(1),
          });

      _messageController.clear();

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
            'role': 'support',
            'senderType': 'tech',
            'from': 'tech',
            'techId': user.uid,
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
            'unreadByCustomer': FieldValue.increment(1),
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
      builder:
          (context) => SafeArea(
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

  void _showFullImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
              body: Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    placeholder:
                        (context, url) => CircularProgressIndicator(
                          color: AppColors.primaryCyan,
                        ),
                    errorWidget:
                        (context, url, error) => const Icon(
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

  Future<void> _markComplete() async {
    try {
      await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.roomId)
          .update({
            'status': 'completed',
            'hasLiveTech': false,
            'completedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat marked as complete')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error marking complete: $e');
    }
  }

  Future<void> _deleteRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            title: const Text(
              'Delete Chat',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this chat? This cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('supportRooms')
            .doc(widget.roomId)
            .delete();

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Error deleting: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryCyan),
          ),
        ),
      );
    }

    final customerName =
        _roomData?['customerName'] ??
        _roomData?['customerEmail'] ??
        _userData?['name'] ??
        _userData?['email'] ??
        _roomData?['userEmail'] ??
        _roomData?['phone'] ??
        'Unknown Customer';

    final status = _roomData?['status'] ?? 'unknown';
    final statusColor = _getStatusColor(status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
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
                Flexible(
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_assignedToName != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.person, size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _assignedToName!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
            onPressed: _markComplete,
            tooltip: 'Mark Complete',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteRoom,
            tooltip: 'Delete',
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6, color: Colors.white70),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Column(
        children: [
          // Customer Info Card
          if (_roomData != null) _buildCustomerInfoCard(),

          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('supportRooms')
                      .doc(widget.roomId)
                      .collection('messages')
                      .snapshots(),
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

                if (snapshot.hasError) {
                  debugPrint('Messages stream error: ${snapshot.error}');
                  return Center(
                    child: Text(
                      'Error loading messages',
                      style: TextStyle(color: AppColors.error),
                    ),
                  );
                }

                var messages = snapshot.data?.docs ?? [];

                // Sort messages manually to handle both old (timestamp) and new (createdAt) fields
                messages =
                    messages.toList()..sort((a, b) {
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

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                // Auto-scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final data = msg.data() as Map<String, dynamic>;
                    return _buildMessageBubble(data);
                  },
                );
              },
            ),
          ),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    final intakeData = _roomData?['intakeData'] as Map<String, dynamic>?;
    final hasIntake = intakeData != null && intakeData.isNotEmpty;
    final email =
        (_roomData?['customerEmail'] ??
                _roomData?['userEmail'] ??
                _userData?['email'])
            ?.toString();
    final phone =
        (_roomData?['phone'] ??
                _userData?['phoneNumber'] ??
                _userData?['phone'])
            ?.toString();

    return Container(
      margin: const EdgeInsets.all(16),
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
              const Icon(
                Icons.info_outline,
                color: AppColors.primaryCyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Customer Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_roomData?['accountType'] == 'free_trial')
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
          if ((email != null && email.isNotEmpty) ||
              (phone != null && phone.isNotEmpty)) ...[
            const SizedBox(height: 12),
            if (email != null && email.isNotEmpty)
              _buildInfoRow('✉️ Email', email),
            if (phone != null && phone.isNotEmpty)
              _buildInfoRow('📞 Phone', phone),
          ],
          if (hasIntake) ...[
            const SizedBox(height: 12),
            if (intakeData['equipmentType'] != null)
              _buildInfoRow('🏠 Equipment Type', intakeData['equipmentType']),
            if (intakeData['problemDescription'] != null)
              _buildInfoRow('⚠️ Problem', intakeData['problemDescription']),
            if (intakeData['equipmentAge'] != null)
              _buildInfoRow('📅 Age', intakeData['equipmentAge']),
            if (intakeData['brand'] != null)
              _buildInfoRow('🏭 Brand/Model', intakeData['brand']),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'No intake form data available',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data) {
    final isTech = data['senderType'] == 'tech' || data['from'] == 'tech';
    final isAI = data['senderType'] == 'ai' || data['from'] == 'ai';
    final text = data['messageText'] ?? data['text'] ?? '';
    final timestamp = data['createdAt'] ?? data['timestamp'];
    final imageUrl = data['imageUrl'] as String?;

    Color bubbleColor;
    Color textColor;
    String senderLabel;

    if (isAI) {
      bubbleColor = const Color(0xFF3B3B4F);
      textColor = Colors.white;
      senderLabel = '🤖 AI Assistant';
    } else if (isTech) {
      bubbleColor = AppColors.primaryCyan.withOpacity(0.2);
      textColor = Colors.white;
      senderLabel = 'You (Support)';
    } else {
      bubbleColor = AppColors.surfaceDark;
      textColor = Colors.white;
      senderLabel = 'Customer';
    }

    return Align(
      alignment: isTech ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isTech ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              senderLabel,
              style: TextStyle(
                color: isAI ? AppColors.primaryCyan : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(12),
                border:
                    isAI
                        ? Border.all(
                          color: AppColors.primaryCyan.withOpacity(0.3),
                        )
                        : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GestureDetector(
                        onTap: () => _showFullImage(context, imageUrl),
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
                    if (text != '📷 Image' && text.isNotEmpty)
                      const SizedBox(height: 8),
                  ],
                  if (text != '📷 Image' || imageUrl == null)
                    Text(
                      text,
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                ],
              ),
            ),
            if (timestamp != null) ...[
              const SizedBox(height: 2),
              Text(
                _formatTimestamp(timestamp),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
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
                  icon: Icon(Icons.attach_file, color: AppColors.primaryCyan),
                  onPressed: () => _showImageSourceDialog(),
                  tooltip: 'Attach image',
                ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type your response...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primaryCyan,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'claimed' || s == 'active' || s == 'assigned') {
      return Colors.green;
    } else if (s == 'unclaimed' || s == 'new' || s == 'pending') {
      return Colors.orange;
    } else if (s == 'completed') {
      return Colors.blue;
    }
    return Colors.grey;
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      DateTime dt;
      if (timestamp is Timestamp) {
        dt = timestamp.toDate();
      } else if (timestamp is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return '';
      }

      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) {
        return 'Just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else {
        return DateFormat('MMM d, h:mm a').format(dt);
      }
    } catch (e) {
      return '';
    }
  }
}
