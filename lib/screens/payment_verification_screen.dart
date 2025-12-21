import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/payment_service.dart';

/// Utility screen to verify Stripe payment configuration
/// Use this for testing and debugging payment setup
class PaymentVerificationScreen extends StatefulWidget {
  const PaymentVerificationScreen({super.key});

  @override
  State<PaymentVerificationScreen> createState() =>
      _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState extends State<PaymentVerificationScreen> {
  final List<VerificationCheck> _checks = [];
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _runVerification();
  }

  Future<void> _runVerification() async {
    setState(() {
      _isChecking = true;
      _checks.clear();
    });

    // Check 1: Firebase initialized
    await _checkFirebase();

    // Check 2: Stripe settings in Firestore
    await _checkStripeSettings();

    // Check 3: Payment service initialization
    await _checkPaymentService();

    // Check 4: Google Pay availability
    await _checkGooglePay();

    setState(() {
      _isChecking = false;
    });
  }

  Future<void> _checkFirebase() async {
    try {
      final app = Firebase.app();
      _addCheck(
        'Firebase',
        true,
        'Firebase initialized: ${app.name}',
      );
    } catch (e) {
      _addCheck(
        'Firebase',
        false,
        'Firebase not initialized: $e',
      );
    }
  }

  Future<void> _checkStripeSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('stripe')
          .get();

      if (doc.exists) {
        final data = doc.data();
        final hasPublishableKey = data?['publishableKey'] != null;
        final hasUrl = data?['createPaymentIntentUrl'] != null;

        if (hasPublishableKey && hasUrl) {
          _addCheck(
            'Stripe Settings',
            true,
            'Stripe configuration found in Firestore',
          );
        } else {
          final missing = [];
          if (!hasPublishableKey) missing.add('publishableKey');
          if (!hasUrl) missing.add('createPaymentIntentUrl');
          _addCheck(
            'Stripe Settings',
            false,
            'Missing fields: ${missing.join(", ")}',
          );
        }
      } else {
        _addCheck(
          'Stripe Settings',
          false,
          'settings/stripe document not found in Firestore',
        );
      }
    } catch (e) {
      _addCheck(
        'Stripe Settings',
        false,
        'Error checking Firestore: $e',
      );
    }
  }

  Future<void> _checkPaymentService() async {
    try {
      final paymentService = PaymentService();
      await paymentService.initialize();
      _addCheck(
        'Payment Service',
        true,
        'Payment service initialized successfully',
      );
    } catch (e) {
      _addCheck(
        'Payment Service',
        false,
        'Failed to initialize payment service: $e',
      );
    }
  }

  Future<void> _checkGooglePay() async {
    try {
      final paymentService = PaymentService();
      final isAvailable = await paymentService.isGooglePayAvailable();
      _addCheck(
        'Google Pay',
        isAvailable,
        isAvailable
            ? 'Google Pay is available on this device'
            : 'Google Pay is not available (device may not support it)',
      );
    } catch (e) {
      _addCheck(
        'Google Pay',
        false,
        'Error checking Google Pay: $e',
      );
    }
  }

  void _addCheck(String name, bool passed, String message) {
    setState(() {
      _checks.add(VerificationCheck(
        name: name,
        passed: passed,
        message: message,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final allPassed = _checks.isNotEmpty && _checks.every((c) => c.passed);
    final anyFailed = _checks.any((c) => !c.passed);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Payment System Verification'),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isChecking ? null : _runVerification,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status banner
            if (!_isChecking && _checks.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: allPassed ? Colors.green.shade900 : Colors.red.shade900,
                child: Row(
                  children: [
                    Icon(
                      allPassed ? Icons.check_circle : Icons.error,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        allPassed
                            ? 'All checks passed! Payment system is ready.'
                            : 'Some checks failed. Review issues below.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Checks list
            Expanded(
              child: _isChecking
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF4EC7F3),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Running verification checks...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _checks.length,
                      itemBuilder: (context, index) {
                        final check = _checks[index];
                        return Card(
                          color: const Color(0xFF1A1A1A),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      check.passed
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color: check.passed
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        check.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  check.message,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Instructions for failed checks
            if (anyFailed && !_isChecking)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📖 Next Steps',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Review docs/PAYMENT_SETUP.md for configuration instructions.',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
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
}

class VerificationCheck {
  final String name;
  final bool passed;
  final String message;

  VerificationCheck({
    required this.name,
    required this.passed,
    required this.message,
  });
}
