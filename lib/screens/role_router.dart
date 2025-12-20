import 'package:flutter/material.dart';
import 'main_navigation_screen.dart';
import 'chat_screen.dart';

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
