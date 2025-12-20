import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main_navigation_screen.dart';
import '../services/notification_service.dart';
import '../services/call_recording_service.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/safety_disclaimer.dart';
import '../widgets/call_recording_opt_in_dialog.dart';

class AuthScreen extends StatefulWidget {
  final bool isTechnician;
  final VoidCallback onToggleTheme;

  const AuthScreen({
    super.key,
    required this.isTechnician,
    required this.onToggleTheme,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool isLogin = true;
  bool showPassword = false;
  bool rememberMe = true;
  String errorMsg = '';

  Future<void> _submit() async {
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      UserCredential userCredential;
      if (isLogin) {
        userCredential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        // Try to create user, if email exists, send reset email
        try {
          // Optional: enforce confirm password match
          if (_confirmPasswordController.text.trim() != password) {
            setState(() => errorMsg = 'Passwords do not match.');
            return;
          }
          userCredential = await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            await auth.sendPasswordResetEmail(email: email);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reset email sent. Check your inbox.'),
              ),
            );
            return; // Do not proceed to create user
          } else {
            rethrow;
          }
        }
        // Optional: enforce confirm password match
        if (_confirmPasswordController.text.trim() != password) {
          setState(() => errorMsg = 'Passwords do not match.');
          return;
        }
        userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Send email verification
        await userCredential.user?.sendEmailVerification();

        // Show verification email sent message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Verification email sent! Please check your inbox.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      final user = userCredential.user;
      if (user == null) throw Exception('User creation failed');

      // Fetch user role from Firestore
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final role = userDoc.data()?['role'] as String? ?? 'user';

      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('firebase_uid', user.uid);
        await prefs.setString('user_role', role);
      }

      // Register FCM token for push notifications
      await NotificationService().onUserLogin();

      if (!mounted) return;

      // Show call recording opt-in during signup for non-admin users
      if (!isLogin && role != 'admin') {
        final consent = await showCallRecordingOptIn(context);
        if (consent != null) {
          await saveCallRecordingConsent(user.uid, consent);
          // Initialize call recording service if user consented
          if (consent) {
            final callService = CallRecordingService();
            await callService.initialize(user.uid, consent);
          }
        }
      }

      if (!mounted) return;

      // Show safety disclaimer for non-admin users
      if (role != 'admin') {
        final accepted = await SafetyDisclaimer.show(context);
        if (!accepted) {
          // User declined - sign them out
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'You must accept the safety disclaimer to use this app.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (!mounted) return;

      Widget nextScreen = MainNavigationScreen(
        onToggleTheme: widget.onToggleTheme,
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => nextScreen),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Auth error: ${e.message}');
      setState(() => errorMsg = e.message ?? 'Login failed. Please try again.');
    } catch (e) {
      debugPrint('❌ Login error: $e');
      setState(() => errorMsg = 'Login failed. Please check your credentials.');
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot Password'),
        content: const Text(
          'A password reset email will be sent to your email address.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final email = _emailController.text.trim();
              if (email.isNotEmpty) {
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: email,
                  );
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Reset email sent!')),
                    );
                  }
                } catch (e) {
                  debugPrint('Password reset error: $e');
                }
              }
            },
            child: const Text('Send Reset Email'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Login' : 'Register'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: AutofillGroup(
          child: ListView(
            children: [
              const SizedBox(height: 20),
              // Logo
              Center(
                child: Image.asset(
                  'assets/logos/tekneck_dark.jpeg',
                  width: 120,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.ac_unit,
                    size: 80,
                    color: AppColors.primaryCyan,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Email field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.email, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceDark.withOpacity(0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppColors.primaryCyan,
                      width: 2,
                    ),
                  ),
                ),
                style: TextStyle(color: AppColors.textPrimary),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.email,
                  AutofillHints.username,
                ],
              ),
              const SizedBox(height: 16),
              // Password field
              TextField(
                controller: _passwordController,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.lock, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceDark.withOpacity(0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppColors.primaryCyan,
                      width: 2,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showPassword ? Icons.visibility : Icons.visibility_off,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                  ),
                ),
                style: TextStyle(color: AppColors.textPrimary),
                autofillHints: const [AutofillHints.password],
              ),
              if (!isLogin) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceDark.withOpacity(0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.primaryCyan,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(color: AppColors.textPrimary),
                  autofillHints: const [AutofillHints.newPassword],
                ),
              ],
              CheckboxListTile(
                value: rememberMe,
                onChanged: (val) => setState(() => rememberMe = val ?? true),
                title: Text(
                  'Remember Me',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primaryCyan,
                checkColor: Colors.white,
              ),
              const SizedBox(height: 24),
              GradientButton(
                text: isLogin ? 'Login' : 'Create Account',
                onPressed: _submit,
                width: double.infinity,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(
                  isLogin
                      ? 'Create a new account'
                      : 'Already have an account? Login',
                  style: TextStyle(color: AppColors.primaryCyan),
                ),
              ),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              if (errorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    errorMsg,
                    style: const TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
