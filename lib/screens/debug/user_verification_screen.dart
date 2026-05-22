import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/gradient_scaffold.dart';
import '../../services/payment_service.dart';

/// Debug screen to verify user authentication and Stripe configuration
class UserVerificationScreen extends StatefulWidget {
  const UserVerificationScreen({super.key});

  @override
  State<UserVerificationScreen> createState() => _UserVerificationScreenState();
}

class _UserVerificationScreenState extends State<UserVerificationScreen> {
  final PaymentService _paymentService = PaymentService();
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _stripeConfig;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'No user signed in';
          _isLoading = false;
        });
        return;
      }

      // Load user document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Load Stripe configuration
      final stripeDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('stripe')
          .get();

      // Initialize Stripe
      await _paymentService.initialize();

      setState(() {
        _userData = {
          'uid': user.uid,
          'email': user.email,
          'emailVerified': user.emailVerified,
          'firestoreData': userDoc.exists ? userDoc.data() : null,
        };
        _stripeConfig = stripeDoc.exists ? stripeDoc.data() : null;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        _error = 'Error loading data: $e\n$stackTrace';
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.verified_user,
                      size: 48, color: Color(0xFF4EC7F3)),
                  const SizedBox(height: 16),
                  const Text(
                    'User Verification',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Debug user authentication and Stripe config',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error,
                                    color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadUserData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSection('Firebase Auth', _userData),
                              const SizedBox(height: 16),
                              _buildSection('Stripe Config', _stripeConfig),
                            ],
                          ),
                        ),
            ),

            // Refresh Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loadUserData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4EC7F3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Map<String, dynamic>? data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                data != null ? Icons.check_circle : Icons.error,
                color: data != null ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data == null)
            const Text(
              'No data found',
              style: TextStyle(color: Colors.red),
            )
          else
            ..._buildDataRows(data),
        ],
      ),
    );
  }

  List<Widget> _buildDataRows(Map<String, dynamic> data) {
    return data.entries.map((entry) {
      final value = entry.value is Map
          ? '\n${_formatMap(entry.value as Map)}'
          : entry.value.toString();

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                entry.key,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () => _copyToClipboard(value),
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
              onPressed: () => _copyToClipboard(value),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _formatMap(Map map) {
    return map.entries.map((e) => '  ${e.key}: ${e.value}').join('\n');
  }
}
