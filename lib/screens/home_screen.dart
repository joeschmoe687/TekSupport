import 'package:flutter/material.dart';
import 'welcome_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import '../widgets/gradient_scaffold.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomeScreen({super.key, required this.onToggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    WelcomeScreen(onToggleTheme: widget.onToggleTheme),
    ChatScreen(onToggleTheme: widget.onToggleTheme),
    SettingsScreen(onToggleTheme: widget.onToggleTheme),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: AppColors.surfaceDark),
        child: SafeArea(
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: AppColors.primaryCyan,
            unselectedItemColor: AppColors.textSecondary,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
