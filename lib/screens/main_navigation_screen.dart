import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/gradient_scaffold.dart';
import 'settings_screen.dart';
import 'tech_inbox_screen.dart';
import 'admin_chat_sessions_screen.dart';
import 'admin_dashboard_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const MainNavigationScreen({super.key, required this.onToggleTheme});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // Initialize to safe defaults; will be updated after role is loaded
  List<Widget> _screens = [];
  List<BottomNavigationBarItem> _navItems = [];
  String _userRole = 'user';

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  Future<void> _initializeNavigation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _userRole = 'user';
      } else {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        _userRole = userDoc.data()?['role'] as String? ?? 'user';
      }
    } catch (e) {
      debugPrint('Error loading role, defaulting to user: $e');
      _userRole = 'user';
    }

    setState(() {
      if (_userRole == 'admin') {
        // Admin chat-only interface: Chats → Admin Dashboard → Settings
        _screens = [
          AdminChatSessionsScreen(onToggleTheme: widget.onToggleTheme),
          AdminDashboardScreen(onToggleTheme: widget.onToggleTheme),
          SettingsScreen(onToggleTheme: widget.onToggleTheme),
        ];
        _navItems = const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ];
      } else if (_userRole == 'tech') {
        // Tech chat-only interface: Inbox → Settings
        _screens = [
          TechInboxScreen(onToggleTheme: widget.onToggleTheme),
          SettingsScreen(onToggleTheme: widget.onToggleTheme),
        ];
        _navItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.inbox), label: 'Inbox'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ];
      }
      // Note: Regular users are handled by ChatScreen in RoleRouter, not here
    });

    debugPrint('🧠 Logged in as: $_userRole');
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      extendBodyBehindAppBar: false,
      body: _screens.isEmpty
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primaryCyan),
            )
          : _screens[_selectedIndex],
      bottomNavigationBar: _navItems.isEmpty
          ? null
          : SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.95),
                  border: Border(
                    top: BorderSide(color: AppColors.border.withOpacity(0.5)),
                  ),
                ),
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  selectedItemColor: AppColors.primaryCyan,
                  unselectedItemColor: AppColors.textSecondary,
                  selectedFontSize: 11,
                  unselectedFontSize: 10,
                  items: _navItems,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                ),
              ),
            ),
    );
  }
}
