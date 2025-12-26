import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service to handle Stripe payments and Google Pay integration
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  bool _isInitialized = false;
  String? _publishableKey;
  String? _merchantId;
  bool _isTestMode = true; // Determined by publishable key prefix

  /// Initialize Stripe with publishable key from Firestore
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Fetch Stripe configuration from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('stripe')
          .get();

      if (doc.exists) {
        _publishableKey = doc.data()?['publishableKey'] as String?;
        _merchantId = doc.data()?['merchantId'] as String?;

        if (_publishableKey != null) {
          Stripe.publishableKey = _publishableKey!;
          if (_merchantId != null) {
            Stripe.merchantIdentifier = _merchantId!;
          }
          // Determine test mode from key prefix
          _isTestMode = _publishableKey!.startsWith('pk_test_');
          _isInitialized = true;
          debugPrint(
              '✅ Stripe initialized successfully (${_isTestMode ? "TEST" : "LIVE"} mode)');
        } else {
          debugPrint('⚠️ Stripe publishable key not found in Firestore');
        }
      } else {
        debugPrint('⚠️ Stripe settings document not found in Firestore');
      }
    } catch (e) {
      debugPrint('❌ Error initializing Stripe: $e');
    }
  }

  /// Create a payment intent on the server
  /// Returns the client secret for confirming payment
  ///
  /// Note: This method supports guest payments. If the user is not signed
  /// in the app will still attempt to create a payment intent by sending
  /// nullable `userId` and `email` fields to the backend.
  Future<String?> createPaymentIntent({
    required int amountCents,
    required String currency,
    required String description,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Allow guest payments: log and continue with nullable fields
        debugPrint('⚠️ User not authenticated, proceeding as guest');
      }

      // Get the Cloud Function URL from Firestore settings
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('stripe')
          .get();

      final createPaymentIntentUrl =
          doc.data()?['createPaymentIntentUrl'] as String?;
      if (createPaymentIntentUrl == null) {
        throw Exception('Payment Intent URL not configured');
      }

      // Call the Cloud Function to create payment intent
      final response = await http.post(
        Uri.parse(createPaymentIntentUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': amountCents,
          'currency': currency,
          'description': description,
          'userId': user?.uid,
          'email': user?.email,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['clientSecret'] as String?;
      } else {
        debugPrint('❌ Failed to create payment intent: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error creating payment intent: $e');
      return null;
    }
  }

  /// Process payment with card details
  Future<PaymentResult> processCardPayment({
    required BuildContext context,
    required int amountCents,
    required String supportType,
    required String description,
  }) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) {
        return PaymentResult(
          success: false,
          error: 'Payment system not initialized',
        );
      }
    }

    try {
      // Create payment intent
      final clientSecret = await createPaymentIntent(
        amountCents: amountCents,
        currency: 'usd',
        description: description,
      );

      if (clientSecret == null) {
        return PaymentResult(
          success: false,
          error: 'Failed to create payment intent',
        );
      }

      // Present card form to user
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'TekNeck Support',
          style: ThemeMode.dark,
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            currencyCode: 'USD',
            testEnv: _isTestMode, // Use test mode based on key type
          ),
        ),
      );

      // Show payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Payment successful - log transaction
      await _logTransaction(
        supportType: supportType,
        amountCents: amountCents,
        status: 'completed',
        paymentMethod: 'card',
      );

      return PaymentResult(success: true);
    } on StripeException catch (e) {
      debugPrint('❌ Stripe error: ${e.error.message}');
      return PaymentResult(
        success: false,
        error: e.error.message ?? 'Payment failed',
        cancelled: e.error.code == FailureCode.Canceled,
      );
    } catch (e) {
      debugPrint('❌ Payment error: $e');
      return PaymentResult(
        success: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  /// Process payment with Google Pay
  Future<PaymentResult> processGooglePayPayment({
    required BuildContext context,
    required int amountCents,
    required String supportType,
    required String description,
  }) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) {
        return PaymentResult(
          success: false,
          error: 'Payment system not initialized',
        );
      }
    }

    try {
      // Create payment intent
      final clientSecret = await createPaymentIntent(
        amountCents: amountCents,
        currency: 'usd',
        description: description,
      );

      if (clientSecret == null) {
        return PaymentResult(
          success: false,
          error: 'Failed to create payment intent',
        );
      }

      // Check if Google Pay is available
      final isPlatformPaySupported =
          await Stripe.instance.isPlatformPaySupported();

      if (!isPlatformPaySupported) {
        return PaymentResult(
          success: false,
          error: 'Platform Pay is not available on this device',
        );
      }

      // Initialize Google Pay payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'TekNeck Support',
          style: ThemeMode.dark,
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            currencyCode: 'USD',
            testEnv: _isTestMode, // Use test mode based on key type
          ),
        ),
      );

      // Present Google Pay directly
      await Stripe.instance.presentPaymentSheet();

      // Payment successful - log transaction
      await _logTransaction(
        supportType: supportType,
        amountCents: amountCents,
        status: 'completed',
        paymentMethod: 'google_pay',
      );

      return PaymentResult(success: true);
    } on StripeException catch (e) {
      debugPrint('❌ Google Pay error: ${e.error.message}');
      return PaymentResult(
        success: false,
        error: e.error.message ?? 'Google Pay payment failed',
        cancelled: e.error.code == FailureCode.Canceled,
      );
    } catch (e) {
      debugPrint('❌ Google Pay error: $e');
      return PaymentResult(
        success: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  /// Log transaction to Firestore
  Future<void> _logTransaction({
    required String supportType,
    required int amountCents,
    required String status,
    required String paymentMethod,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('supportTransactions').add({
        'userId': user.uid,
        'email': user.email,
        'type': supportType,
        'amount': amountCents / 100, // Convert to dollars
        'amountCents': amountCents,
        'timestamp': FieldValue.serverTimestamp(),
        'status': status,
        'paymentMethod': paymentMethod,
        'platform': 'flutter_app',
      });

      debugPrint('✅ Transaction logged: $supportType - \$${amountCents / 100}');
    } catch (e) {
      debugPrint('❌ Error logging transaction: $e');
    }
  }

  /// Check if Platform Pay (Google Pay / Apple Pay) is available
  Future<bool> isPlatformPayAvailable() async {
    try {
      return await Stripe.instance.isPlatformPaySupported();
    } catch (e) {
      debugPrint('Error checking platform pay availability: $e');
      return false;
    }
  }
}

/// Result of a payment operation
class PaymentResult {
  final bool success;
  final String? error;
  final bool cancelled;

  PaymentResult({
    required this.success,
    this.error,
    this.cancelled = false,
  });
}
