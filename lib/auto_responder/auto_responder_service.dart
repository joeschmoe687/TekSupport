// 📦 Imports
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

/// AutoResponderService
/// Native Android SMS auto-responder for admin users
/// Intercepts incoming SMS and sends auto-reply during off-hours
class AutoResponderService {
  static const _channel =
      MethodChannel('com.tekneckjoe.hvacsupport/sms_autoresponder');

  bool _isRunning = false;

  static const String _enabledKey = 'autoResponderEnabled';
  static const String _startHourKey = 'autoResponderStartHour';
  static const String _endHourKey = 'autoResponderEndHour';
  static const String _autoReplyTextKey = 'autoReplyText';

  /// Check if SMS permissions are granted
  static Future<bool> checkPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkSmsPermissions');
      return result ?? false;
    } catch (e) {
      log('❌ Error checking SMS permissions: $e');
      return false;
    }
  }

  /// Request SMS permissions from the user
  static Future<void> requestPermissions() async {
    try {
      await _channel.invokeMethod('requestSmsPermissions');
      log('📱 SMS permissions requested');
    } catch (e) {
      log('❌ Error requesting SMS permissions: $e');
    }
  }

  /// Get full auto-responder status from native side
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _channel.invokeMethod<Map>('getAutoResponderStatus');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      log('❌ Error getting auto-responder status: $e');
      return {};
    }
  }

  /// Enable/disable auto-responder (syncs to native Android)
  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel
          .invokeMethod('setAutoResponderEnabled', {'enabled': enabled});

      // Also save to SharedPreferences for Flutter side
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);

      log('✅ Auto-responder ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      log('❌ Error setting auto-responder enabled: $e');
    }
  }

  /// Set auto-reply text (syncs to native Android)
  static Future<void> setReplyText(String text) async {
    try {
      await _channel.invokeMethod('setAutoReplyText', {'text': text});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_autoReplyTextKey, text);

      log('✅ Auto-reply text updated');
    } catch (e) {
      log('❌ Error setting auto-reply text: $e');
    }
  }

  /// Set response time window (syncs to native Android)
  static Future<void> setReplyHours(int startHour, int endHour) async {
    try {
      await _channel.invokeMethod('setAutoReplyHours', {
        'startHour': startHour,
        'endHour': endHour,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_startHourKey, startHour);
      await prefs.setInt(_endHourKey, endHour);

      log('✅ Auto-reply hours set: $startHour:00 - $endHour:00');
    } catch (e) {
      log('❌ Error setting auto-reply hours: $e');
    }
  }

  /// Send a test SMS (for testing the auto-responder)
  static Future<bool> sendTestSms(String phoneNumber, String message) async {
    try {
      final result = await _channel.invokeMethod<bool>('sendTestSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      return result ?? false;
    } catch (e) {
      log('❌ Error sending test SMS: $e');
      return false;
    }
  }

  /// Log auto-reply to Firestore for auditing
  static Future<void> logAutoReply({
    required String toNumber,
    required String message,
    required String type, // missed_call, missed_text, dnd
  }) async {
    try {
      await FirebaseFirestore.instance.collection('autoReplies').add({
        'toNumber': toNumber,
        'message': message,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      log('❌ Error logging auto-reply: $e');
    }
  }

  /// Initialize auto-responder service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool(_enabledKey) ?? false;

    if (!isEnabled) {
      log('📱 Auto-responder is disabled');
      return;
    }

    // Check permissions
    final hasPermissions = await checkPermissions();
    if (!hasPermissions) {
      log('⚠️ SMS permissions not granted - auto-responder inactive');
      return;
    }

    // Sync settings to native side
    final startHour = prefs.getInt(_startHourKey) ?? 7;
    final endHour = prefs.getInt(_endHourKey) ?? 19;
    final replyText = prefs.getString(_autoReplyTextKey) ??
        "Hi! Thanks for messaging. I'm currently unavailable but will get back to you soon. - TekNeck HVAC Support";

    await setReplyHours(startHour, endHour);
    await setReplyText(replyText);
    await setEnabled(true);

    log('✅ Auto-responder initialized');
    log('📱 Active hours: Outside $startHour:00 - $endHour:00');
  }

  /// Start service
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    log('✅ AutoResponderService started');
  }
}
