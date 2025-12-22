import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service for automatically logging errors to Firebase Firestore.
/// Captures uncaught Flutter errors and platform errors.
class ErrorLogService {
  static final ErrorLogService _instance = ErrorLogService._internal();
  factory ErrorLogService() => _instance;
  ErrorLogService._internal();

  bool _initialized = false;
  String? _deviceInfo;
  String? _appVersion;
  bool _isLoggingError = false; // Prevent recursive error logging
  
  /// Initialize the error logging service.
  /// Sets up global error handlers for Flutter and platform errors.
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Get device and app info
      await _loadDeviceInfo();
      
      // Set up Flutter error handler
      FlutterError.onError = (FlutterErrorDetails details) {
        // Log to console in debug mode
        FlutterError.presentError(details);
        
        // Send to Firebase
        _logError(
          error: details.exception.toString(),
          stackTrace: details.stack?.toString(),
          context: details.context?.toString(),
          library: details.library,
          fatal: false,
        );
      };
      
      // Set up platform error handler (for errors outside Flutter)
      PlatformDispatcher.instance.onError = (error, stack) {
        _logError(
          error: error.toString(),
          stackTrace: stack.toString(),
          fatal: true,
        );
        return true; // Handled
      };
      
      _initialized = true;
      debugPrint('[ErrorLogService] Initialized successfully');
    } catch (e) {
      debugPrint('[ErrorLogService] Failed to initialize: $e');
    }
  }
  
  /// Load device and app information for error context
  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceInfo = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt}) - ${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceInfo = 'iOS ${iosInfo.systemVersion} - ${iosInfo.model}';
      } else {
        _deviceInfo = 'Unknown platform';
      }
    } catch (e) {
      _deviceInfo = 'Failed to load device info';
      debugPrint('[ErrorLogService] Failed to load device info: $e');
    }
  }
  
  /// Manually log an error to Firebase
  Future<void> logError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
  }) async {
    await _logError(
      error: error.toString(),
      stackTrace: stackTrace?.toString(),
      context: context,
      additionalData: additionalData,
    );
  }
  
  /// Internal method to log error to Firebase
  Future<void> _logError({
    required String error,
    String? stackTrace,
    String? context,
    String? library,
    bool fatal = false,
    Map<String, dynamic>? additionalData,
  }) async {
    // Prevent recursive error logging
    if (_isLoggingError) {
      debugPrint('[ErrorLogService] Skipping recursive error log');
      return;
    }
    
    _isLoggingError = true;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      final timestamp = DateTime.now();
      
      final errorData = {
        'error': error,
        'stackTrace': stackTrace,
        'context': context,
        'library': library,
        'fatal': fatal,
        'timestamp': FieldValue.serverTimestamp(),
        'clientTimestamp': timestamp.toIso8601String(),
        'userId': user?.uid,
        'userEmail': user?.email,
        'deviceInfo': _deviceInfo,
        'appVersion': _appVersion,
        'platform': Platform.operatingSystem,
        ...?additionalData,
      };
      
      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('app_error_logs')
          .add(errorData);
      
      debugPrint('[ErrorLogService] Error logged to Firebase: ${error.substring(0, error.length > 100 ? 100 : error.length)}');
    } catch (e) {
      // Don't let error logging itself crash the app
      // Don't try to log this error to prevent infinite recursion
      debugPrint('[ErrorLogService] Failed to log error to Firebase: $e');
    } finally {
      _isLoggingError = false;
    }
  }
}
