import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

/// AutoResponderSettings
/// DEPRECATED: Telephony package no longer maintained
/// Phase 2 will implement native Android SMS broadcast receiver
class AutoResponderService {
  static const String _enabledKey = 'autoResponderEnabled';
  static const String _startHourKey = 'autoResponderStartHour';
  static const String _endHourKey = 'autoResponderEndHour';
  static const String _autoReplyTextKey = 'autoReplyText';

  void start() async {
    log(
      '⚠️ AutoResponder: Telephony package discontinued - waiting for Phase 2',
    );
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  static Future<void> setStartHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_startHourKey, hour);
  }

  static Future<void> setEndHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_endHourKey, hour);
  }

  static Future<void> setAutoReplyText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoReplyTextKey, text);
  }
}
