import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/layout_utils.dart';
import '../widgets/gradient_scaffold.dart';

import 'auth_screen.dart';
import 'main_navigation_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;
  const WelcomeScreen({super.key, required this.onToggleTheme});

  void _handleStartChat(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  AuthScreen(isTechnician: false, onToggleTheme: onToggleTheme),
        ),
      );
    } else {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final role = userDoc.data()?['role'] as String? ?? 'user';

      if (role == 'admin' || role == 'tech') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainNavigationScreen(onToggleTheme: onToggleTheme),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainNavigationScreen(onToggleTheme: onToggleTheme),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = safeScreenPadding(context);

    return GradientScaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/logos/tekneck_NOback500-500px.png',
                      width: 160,
                    ),
                    SizedBox(height: verticalGap(context, 32)),
                    const Text(
                      'Expert HVAC help—right when you need it.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: verticalGap(context, 16)),
                    Text(
                      'Whether you\'re a DIY homeowner or a seasoned pro, this app connects you to certified HVAC techs for live support, guided troubleshooting, and more.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: verticalGap(context, 24)),
                    Divider(color: AppColors.border),
                    SizedBox(height: verticalGap(context, 24)),
                    const FeatureBullet(
                      text: '✅ Live chat with real HVAC techs',
                    ),
                    const FeatureBullet(
                      text: '🛠️ Step-by-step troubleshooting',
                    ),
                    const FeatureBullet(
                      text: '⏱️ Priority response for subscribers',
                    ),
                    const FeatureBullet(text: '📁 Save and track past issues'),
                    const FeatureBullet(
                      text: '🌗 Light/Dark theme auto support',
                    ),
                    SizedBox(height: verticalGap(context, 32)),
                    GradientButton(
                      text: 'Start Chat',
                      icon: Icons.chat_bubble,
                      onPressed: () => _handleStartChat(context),
                      width: 200,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class FeatureBullet extends StatelessWidget {
  final String text;
  const FeatureBullet({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, color: Colors.white),
      ),
    );
  }
}
