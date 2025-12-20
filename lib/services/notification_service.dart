import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Handles FCM push notifications for the app
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize notifications - call this after Firebase.initializeApp()
  Future<void> initialize() async {
    // Request permission (iOS requires explicit permission)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('🔔 Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Get FCM token
      await _getAndSaveToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message tap (when app is in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Check if app was opened from a terminated state via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }
    }
  }

  /// Get FCM token and save to Firestore
  Future<void> _getAndSaveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('🔔 FCM Token: ${token.substring(0, 20)}...');
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Save token to user's Firestore document
  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ No user logged in, cannot save FCM token');
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      }, SetOptions(merge: true));
      debugPrint('✅ FCM token saved to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 Foreground message received:');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    // You can show a local notification or in-app alert here
    // For now, messages will appear in the notification tray
  }

  /// Handle notification tap (opens specific chat)
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('🔔 Notification tapped:');
    debugPrint('   Data: ${message.data}');

    // Navigate to the specific chat room if roomId is provided
    final roomId = message.data['roomId'];
    if (roomId != null) {
      // You can use a navigation key or callback to navigate
      debugPrint('📍 Should navigate to room: $roomId');
    }
  }

  /// Update token when user logs in
  Future<void> onUserLogin() async {
    await _getAndSaveToken();
  }

  /// Clear token when user logs out
  Future<void> onUserLogout() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      } catch (e) {
        debugPrint('Error clearing FCM token: $e');
      }
    }
  }

  /// Subscribe to admin notifications topic
  Future<void> subscribeToAdminNotifications() async {
    await _messaging.subscribeToTopic('admin_notifications');
    debugPrint('✅ Subscribed to admin_notifications topic');
  }

  /// Unsubscribe from admin notifications topic
  Future<void> unsubscribeFromAdminNotifications() async {
    await _messaging.unsubscribeFromTopic('admin_notifications');
    debugPrint('✅ Unsubscribed from admin_notifications topic');
  }
}

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message: ${message.notification?.title}');
  // Background messages are handled by the system notification tray
}
