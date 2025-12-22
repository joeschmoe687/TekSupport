import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'main_navigation_screen.dart';
import 'chat_screen.dart';
import 'live_data_web_screen.dart';

class RoleRouter extends StatelessWidget {
  final String role;
  final VoidCallback onToggleTheme;

  const RoleRouter({
    super.key,
    required this.role,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    // Web routing:
    // For web builds we always route to LiveDataWebScreen, regardless of `role`.
    // Role-based feature gating (e.g. admin-only tools) is handled *inside*
    // LiveDataWebScreen, so `role` is intentionally not used here on web.
    if (kIsWeb) {
      return LiveDataWebScreen(onToggleTheme: onToggleTheme);
    }
    
    // Mobile app routing based on role
    switch (role) {
      case 'admin':
        return MainNavigationScreen(onToggleTheme: onToggleTheme);
      case 'tech':
        return MainNavigationScreen(onToggleTheme: onToggleTheme);
      case 'user':
      default:
        return ChatScreen(onToggleTheme: onToggleTheme);
    }
  }
}
