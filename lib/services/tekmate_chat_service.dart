import 'package:firebase_functions/firebase_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// TekMate Chat Service - ADMIN ONLY (Ghost Mode)
/// This service is completely invisible to non-admin users
/// No TekMate UI, no network calls, no evidence of its existence
class TekMateChatService {
  static final TekMateChatService _instance = TekMateChatService._internal();

  factory TekMateChatService() {
    return _instance;
  }

  TekMateChatService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isAdmin = false;
  bool _isInitialized = false;

  /// Initialize - checks if user is admin
  /// Returns false if user is not admin (TekMate remains hidden)
  Future<bool> init() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _isAdmin = false;
        _isInitialized = true;
        return false;
      }

      // Check admin status from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      _isAdmin = (userData['role'] == 'admin') || (userData['isAdmin'] == true);
      _isInitialized = true;

      return _isAdmin;
    } catch (e) {
      debugPrint('Admin check failed: $e');
      _isAdmin = false;
      _isInitialized = true;
      return false;
    }
  }

  /// Get TekMate response - ADMIN ONLY
  /// Returns null if user is not admin (no error, just silent fail)
  Future<TekMateResponse?> getResponse(
    String message, {
    Map<String, dynamic>? context,
    String platform = 'app',
  }) async {
    if (!_isInitialized) {
      await init();
    }

    // SECURITY: Only admins can call TekMate
    if (!_isAdmin) {
      return null; // Don't reveal TekMate exists
    }

    try {
      final callable = _functions.httpsCallable('tekmateChatProxy');

      final result = await callable.call({
        'message': message,
        'context': context ?? {},
        'platform': platform,
      });

      final data = result.data as Map<dynamic, dynamic>;

      return TekMateResponse(
        response: data['response'] ?? '',
        confidence: (data['confidence'] ?? 0.0).toDouble(),
        autoRespond: data['autoRespond'] ?? false,
      );
    } catch (e) {
      debugPrint('TekMate error: $e');
      return null; // Silent fail - don't expose service
    }
  }

  /// Check if TekMate is available for this user
  bool get isAvailable => _isAdmin;

  /// Check if user is admin
  bool get isAdmin => _isAdmin;
}

/// Response model for TekMate chat
class TekMateResponse {
  final String response;
  final double confidence;
  final bool autoRespond;

  TekMateResponse({
    required this.response,
    required this.confidence,
    required this.autoRespond,
  });

  /// Whether response is high-confidence enough to use
  bool get isHighConfidence => confidence > 0.85;

  /// Whether response should be sent without human review
  bool get shouldAutoRespond => confidence > 0.9;

  /// Confidence as percentage (0-100)
  int get confidencePercent => (confidence * 100).toInt();
}
