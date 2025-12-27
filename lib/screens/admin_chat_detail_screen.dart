import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../widgets/gradient_scaffold.dart';
import '../services/tekmate_chat_service.dart';
import '../services/gemini_chat_service.dart';

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
  final TekMateChatService _tekMateService = TekMateChatService();
  final GeminiChatService _geminiService = GeminiChatService();

  Map<String, dynamic>? _roomData;
  Map<String, dynamic>? _userData;
  String? _assignedToName;
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isTekmateAvailable = false;
  bool _isGeminiAvailable = false;
  bool _isAiLoading = false;
  bool _isTekMateLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRoomData();
    _claimIfNeeded();
    _initAiServices();
  }

  Future<void> _initAiServices() async {
    final tekmateAvailable = await _tekMateService.init();
    final geminiAvailable = await _geminiService.init();
    if (mounted) {
      setState(() {
        _isTekmateAvailable = tekmateAvailable;
        _isGeminiAvailable = geminiAvailable;
      });
    }
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
            'status': 'sent',
            'readBy': [], // Array of user IDs who have read this message
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

  /// Get AI guidance for current conversation (TekMate or Gemini fallback)
  Future<void> _getAiGuidance() async {
    // Get recent messages for context
    final recentMessages = await _getRecentMessages();
    
    // Build context from room data
    final contextData = <String, dynamic>{
      'roomId': widget.roomId,
      'recentMessages': recentMessages,
    };

    if (_roomData != null) {
      if (_roomData!['jobId'] != null) {
        contextData['jobId'] = _roomData!['jobId'];
      }
      if (_roomData!['systemType'] != null) {
        contextData['systemType'] = _roomData!['systemType'];
      }
    }

    setState(() => _isAiLoading = true);

    try {
      // Get the last customer message as the query
      String query = 'Provide guidance for this support conversation';
      if (recentMessages.isNotEmpty) {
        final lastCustomerMsg = recentMessages.firstWhere(
          (msg) => msg['senderType'] == 'customer',
          orElse: () => {},
        );
        if (lastCustomerMsg.isNotEmpty && lastCustomerMsg['text'] != null) {
          query = lastCustomerMsg['text'];
        }
      }

      // Try TekMate first, then fall back to Gemini
      dynamic response;
      String aiSource = '';
      
      if (_isTekmateAvailable) {
        response = await _tekMateService.getResponse(
          query,
          context: contextData,
          platform: 'app',
        );
        aiSource = 'TekMate';
      }
      
      // Fallback to Gemini if TekMate unavailable or failed
      if (response == null && _isGeminiAvailable) {
        final geminiResponse = await _geminiService.getResponse(
          query,
          context: contextData,
        );
        if (geminiResponse != null) {
          response = geminiResponse;
          aiSource = 'Gemini';
        }
      }

      if (mounted) {
        setState(() => _isAiLoading = false);
      }

      if (response == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI services are temporarily unavailable'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      // Show AI suggestion dialog
      if (mounted) {
        _showAiSuggestionDialog(response, aiSource);
      }
    } catch (e) {
      debugPrint('AI guidance error: $e');
      if (mounted) {
        setState(() => _isAiLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting AI guidance: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Get recent messages for context
  Future<List<Map<String, dynamic>>> _getRecentMessages() async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('supportRooms')
          .doc(widget.roomId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return messagesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'text': data['text'] ?? data['messageText'] ?? '',
          'senderType': data['senderType'] ?? data['from'] ?? 'unknown',
          'timestamp': data['createdAt']?.toDate()?.toIso8601String() ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  /// Show AI suggestion dialog with confidence score
  void _showAiSuggestionDialog(dynamic response, String aiSource) {
    final suggestionController = TextEditingController(text: response.response);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              aiSource == 'TekMate' ? Icons.psychology : Icons.auto_awesome,
              color: aiSource == 'TekMate' 
                  ? AppColors.primaryPurple 
                  : AppColors.primaryCyan,
            ),
            const SizedBox(width: 8),
            Text(
              '$aiSource Suggestion',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Confidence indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getConfidenceColor(response.confidence),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getConfidenceIcon(response.confidence),
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Confidence: ${response.confidencePercent}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Editable suggestion
              TextField(
                controller: suggestionController,
                maxLines: null,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'AI suggestion',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Confidence explanation
              Text(
                response.isHighConfidence
                    ? '✓ High confidence - Review and send'
                    : '⚠ Lower confidence - Verify carefully',
                style: TextStyle(
                  color: response.isHighConfidence
                      ? Colors.green
                      : Colors.orange,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              // Insert suggestion into message field
              _messageController.text = suggestionController.text;
            },
            child: const Text('Use Suggestion'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              // Insert and send
              _messageController.text = suggestionController.text;
              _sendMessage();
            },
            child: const Text('Send Now'),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.85) return Colors.green;
    if (confidence >= 0.70) return Colors.orange;
    return Colors.red;
  }

  IconData _getConfidenceIcon(double confidence) {
    if (confidence >= 0.85) return Icons.check_circle;
    if (confidence >= 0.70) return Icons.info;
    return Icons.warning;
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

  /// TekMate Dialog - ADMIN ONLY (Ghost Mode)
  /// Shows AI-powered response suggestions with confidence scoring
  Future<void> _showTekMateDialog() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Type a message first, then ask TekMate for help'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTekMateLoading = true;
    });

    try {
      // Gather context for TekMate
      final contextData = {
        'roomId': widget.roomId,
        'customerId': _roomData?['userId'] ?? _roomData?['customerUID'],
        'customerName': _userData?['displayName'] ?? _userData?['name'],
        'supportType': _roomData?['supportType'],
        'jobType': _roomData?['jobType'],
      };

      // Get TekMate response
      final response = await _tekMateService.getResponse(
        messageText,
        context: contextData,
        platform: 'app',
      );

      if (!mounted) return;

      setState(() {
        _isTekMateLoading = false;
      });

      if (response == null) {
        // This should never happen for admins, but handle gracefully
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TekMate is not available'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show TekMate response in dialog
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: Row(
            children: [
              Icon(Icons.psychology, color: AppColors.primaryPurple),
              const SizedBox(width: 8),
              const Text(
                'TekMate Suggestion',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Confidence indicator
                Row(
                  children: [
                    const Text(
                      'Confidence: ',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '${response.confidencePercent}%',
                      style: TextStyle(
                        color: response.isHighConfidence
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      response.isHighConfidence
                          ? Icons.check_circle
                          : Icons.warning,
                      color: response.isHighConfidence
                          ? Colors.green
                          : Colors.orange,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Response text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    response.response,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                if (!response.isHighConfidence) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Low confidence - review before sending',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // Copy TekMate response to message field
                _messageController.text = response.response;
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
              ),
              child: const Text('Use This Response'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('TekMate error: $e');
      if (mounted) {
        setState(() {
          _isTekMateLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting TekMate suggestion: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        body: Center(
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
              style: TextStyle(
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
                    style: TextStyle(color: Colors.white70, fontSize: 12),
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
                      style: TextStyle(
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
                  return Center(
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
              Icon(
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
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.white, fontSize: 12),
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
                                child: Center(
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
                  // Read receipt indicator for tech messages
                  if (isTech) ...[
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
            if (timestamp != null) ...[
              const SizedBox(height: 2),
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(color: Colors.white38, fontSize: 10),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI Assistant button (ADMIN ONLY - Ghost Mode)
            // Shows TekMate or Gemini based on availability
            if (_isTekmateAvailable || _isGeminiAvailable)
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: _isAiLoading ? null : _getAiGuidance,
                  icon: _isAiLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryPurple,
                          ),
                        )
                      : Icon(
                          _isTekmateAvailable 
                              ? Icons.psychology 
                              : Icons.auto_awesome,
                          color: _isTekmateAvailable
                              ? AppColors.primaryPurple
                              : AppColors.primaryCyan,
                        ),
                  label: Text(
                    _isAiLoading 
                        ? 'Thinking...' 
                        : _isTekmateAvailable 
                            ? 'Ask TekMate AI' 
                            : 'Ask Gemini AI',
                    style: TextStyle(
                      color: _isTekmateAvailable
                          ? AppColors.primaryPurple
                          : AppColors.primaryCyan,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _isTekmateAvailable
                          ? AppColors.primaryPurple
                          : AppColors.primaryCyan,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            Row(
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
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type your response...',
                      hintStyle: TextStyle(color: Colors.white38),
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
                  decoration: BoxDecoration(
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
            const SizedBox(width: 12),
            // TekMate AI button (admin only)
            if (_isTekmateAvailable) ...[
              _isTekMateLoading
                  ? Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryPurple,
                      ),
                    )
                  : IconButton(
                      icon: Icon(Icons.psychology, color: AppColors.primaryPurple),
                      onPressed: _getTekmateGuidance,
                      tooltip: 'Ask TekMate AI',
                    ),
              const SizedBox(width: 8),
            ],
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
      return Colors.white38; // Sent/Delivered - grey
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

  /// Get TekMate guidance for current message
  /// Shows TekMate dialog with AI-powered response suggestion
  Future<void> _getTekmateGuidance() async {
    await _showTekMateDialog();
  }
}
