import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../widgets/gradient_scaffold.dart';
import 'payment_screen.dart';

class SupportContactScreen extends StatefulWidget {
  const SupportContactScreen({super.key});

  @override
  State<SupportContactScreen> createState() => _SupportContactScreenState();
}

class _SupportContactScreenState extends State<SupportContactScreen> {
  late Map<String, double> _pricing = {};
  bool _isBusinessHours = false;

  @override
  void initState() {
    super.initState();
    _isBusinessHours = _checkBusinessHours();
    _loadPricing();
  }

  bool _checkBusinessHours() {
    final now = DateTime.now();
    // Adjust to CST timezone
    final cstOffset = Duration(hours: -6); // CST is UTC-6
    final cstTime = now.add(cstOffset);

    final hour = cstTime.hour;
    final weekday = cstTime.weekday; // 1 = Monday, 7 = Sunday

    // 9 AM - 5 PM, Monday-Friday
    return hour >= 9 && hour < 17 && weekday >= 1 && weekday <= 5;
  }

  Future<void> _loadPricing() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('pricing')
          .get();

      if (doc.exists) {
        setState(() {
          _pricing = {
            'bizMessage': (doc['bizMessage'] ?? 5).toDouble(),
            'bizPhone': (doc['bizPhone'] ?? 45).toDouble(),
            'bizVideo': (doc['bizVideo'] ?? 60).toDouble(),
            'twentyFourMessage': (doc['twentyFourMessage'] ?? 45).toDouble(),
            'twentyFourPhone': (doc['twentyFourPhone'] ?? 60).toDouble(),
            'twentyFourVideo': (doc['twentyFourVideo'] ?? 80).toDouble(),
          };
        });
      }
    } catch (error) {
      print('Error loading pricing: $error');
    }
  }

  double _getPrice(String type) {
    if (_isBusinessHours) {
      return _pricing['biz$type'] ?? 0.0;
    } else {
      return _pricing['twentyFour$type'] ?? 0.0;
    }
  }

  String _getCurrentCSTTime() {
    final now = DateTime.now();
    final cstOffset = Duration(hours: -6);
    final cstTime = now.add(cstOffset);
    return DateFormat('h:mm a').format(cstTime);
  }

  Future<void> _initiateCall() async {
    // Show payment screen first
    final phonePrice = _getPrice('Phone');
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          supportType: 'phone',
          amountCents: (phonePrice * 100).toInt(),
          description: 'Phone Support - Live phone call with a tech',
        ),
      ),
    );

    // If payment successful, open WhatsApp
    if (result == true && mounted) {
      final message = Uri.encodeComponent('Hi, I need a phone call with support');
      final waLink = 'https://wa.me/message/3OF3QGB7TX2RN1?text=$message';
      try {
        await launchUrl(Uri.parse(waLink), mode: LaunchMode.externalApplication);
      } catch (e) {
        print('Error launching WhatsApp: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

  Future<void> _initiateVideo() async {
    // Show payment screen first
    final videoPrice = _getPrice('Video');
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          supportType: 'video',
          amountCents: (videoPrice * 100).toInt(),
          description: 'Video Call Support - Face-to-face video support',
        ),
      ),
    );

    // If payment successful, show video call options
    if (result == true && mounted) {
      _showVideoCallOptions();
    }
  }

  Future<void> _showVideoCallOptions() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.videocam, color: AppColors.primaryCyan, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Select Video Call App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose your preferred app for the video call:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // WhatsApp option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.phone, color: Color(0xFF25D366)),
                ),
                title: const Text('WhatsApp Video Call',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Most reliable for mobile',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  await _launchVideoCall('whatsapp');
                },
              ),
              
              // Zoom option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D8CFF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam, color: Color(0xFF2D8CFF)),
                ),
                title: const Text('Zoom',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Best for screen sharing',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  await _launchVideoCall('zoom');
                },
              ),
              
              // Google Meet option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00AC47).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.video_call, color: Color(0xFF00AC47)),
                ),
                title: const Text('Google Meet',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Works in browser',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  await _launchVideoCall('meet');
                },
              ),
              
              // FaceTime option (iOS only - but we'll show it anyway)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D448).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.video_camera_front,
                      color: Color(0xFF00D448)),
                ),
                title: const Text('FaceTime',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('iOS only',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  await _launchVideoCall('facetime');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchVideoCall(String platform) async {
    String url;
    
    switch (platform) {
      case 'whatsapp':
        final message = Uri.encodeComponent('Hi, I need a video call with support');
        url = 'https://wa.me/message/3OF3QGB7TX2RN1?text=$message';
        break;
      case 'zoom':
        // In production, this would be a real Zoom meeting link
        url = 'https://zoom.us/j/your_meeting_id';
        break;
      case 'meet':
        // In production, this would be a real Google Meet link
        url = 'https://meet.google.com/your-meeting-code';
        break;
      case 'facetime':
        // FaceTime link format
        url = 'facetime://support@airpronwa.com';
        break;
      default:
        url = 'https://wa.me/message/3OF3QGB7TX2RN1';
    }
    
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error launching $platform: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $platform. Please try another option.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagePrice = _getPrice('Message');
    final phonePrice = _getPrice('Phone');
    final videoPrice = _getPrice('Video');
    final currentTime = _getCurrentCSTTime();
    final timeStatus =
        _isBusinessHours ? '🟢 Business Hours (9-5 CST)' : '🌙 24HR Support';

    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 48,
                    color: Color(0xFF4EC7F3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Support Options',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current time: $currentTime CST',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isBusinessHours
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
            ),

            // Support Options
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Text Chat Card
                    _buildServiceCard(
                      icon: Icons.chat_bubble,
                      title: 'Text Chat',
                      price: messagePrice,
                      onTap: () {
                        // Text chat via web UI
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Text chat available in web app'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Phone Call Card
                    _buildServiceCard(
                      icon: Icons.phone,
                      title: 'Phone Call',
                      price: phonePrice,
                      onTap: _initiateCall,
                      color: const Color(0xFF4EC7F3),
                    ),
                    const SizedBox(height: 12),

                    // Video Call Card
                    _buildServiceCard(
                      icon: Icons.videocam,
                      title: 'Video Call',
                      price: videoPrice,
                      onTap: _initiateVideo,
                      color: const Color(0xFFF093FB),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Back Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required double price,
    required VoidCallback onTap,
    Color color = const Color(0xFF667EEA),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isBusinessHours ? '9-5 CST' : '24HR',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
