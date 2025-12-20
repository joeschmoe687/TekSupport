import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gradient_scaffold.dart';

/// Safety disclaimer that must be accepted before using support features
class SafetyDisclaimer {
  static const String _storageKey = 'tekneck_disclaimer_accepted';
  static const String _versionKey = 'tekneck_disclaimer_version';
  static const String _currentVersion = '1.0';

  /// Check if disclaimer needs to be shown (shows every session for non-admins)
  static Future<bool> needsToShow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Check if admin - skip disclaimer
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final role = userDoc.data()?['role'] as String? ?? 'user';
      if (role == 'admin') return false;
    } catch (e) {
      debugPrint('Error checking user role: $e');
    }

    // Check if already accepted this session
    final prefs = await SharedPreferences.getInstance();
    final acceptedVersion = prefs.getString(_versionKey);
    final acceptedThisSession = prefs.getBool(_storageKey) ?? false;

    // Show if version changed or not accepted this session
    if (acceptedVersion != _currentVersion) return true;
    return !acceptedThisSession;
  }

  /// Mark disclaimer as accepted for this session
  static Future<void> markAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storageKey, true);
    await prefs.setString(_versionKey, _currentVersion);

    // Also log acceptance to Firestore for legal records
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'disclaimerAccepted': true,
              'disclaimerVersion': _currentVersion,
              'disclaimerAcceptedAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        debugPrint('Error logging disclaimer acceptance: $e');
      }
    }
  }

  /// Reset acceptance (for testing or new sessions)
  static Future<void> resetAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Show the disclaimer dialog - returns true if accepted
  static Future<bool> show(BuildContext context) async {
    bool accepted = false;
    bool checkboxChecked = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(242),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: AppColors.surfaceDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.red, width: 2),
                  ),
                  title: Column(
                    children: [
                      const Text('⚠️', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      const Text(
                        'Important Safety Notice',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please read carefully before proceeding',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(38),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withAlpha(77)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '🔥 HVAC Work Hazards',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '• High voltage electrical components can cause electrocution or death\n'
                                '• Refrigerants are toxic and can cause frostbite or asphyxiation\n'
                                '• Gas lines and furnaces pose fire and explosion risks\n'
                                '• Heavy equipment can cause serious injury\n'
                                '• Improper repairs may void warranties or damage equipment',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(38),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withAlpha(77),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '⚖️ Liability Disclaimer',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'TekNeck Support provides informational guidance only. We are NOT liable for:\n\n'
                                '• Personal injury or property damage\n'
                                '• Equipment damage or voided warranties\n'
                                '• Incorrect diagnoses or advice\n'
                                '• Work performed based on our guidance\n\n'
                                'Always consult a licensed professional for complex repairs. '
                                'If you smell gas or suspect a leak, evacuate immediately and call 911.',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        InkWell(
                          onTap:
                              () => setState(
                                () => checkboxChecked = !checkboxChecked,
                              ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  checkboxChecked
                                      ? AppColors.primaryCyan.withAlpha(26)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    checkboxChecked
                                        ? AppColors.primaryCyan
                                        : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: checkboxChecked,
                                  onChanged:
                                      (val) => setState(
                                        () => checkboxChecked = val ?? false,
                                      ),
                                  activeColor: AppColors.primaryCyan,
                                ),
                                Expanded(
                                  child: Text(
                                    'I understand the risks involved with HVAC work and agree that TekNeck Support is not liable for any damages or injuries.',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        accepted = false;
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Decline',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          checkboxChecked
                              ? () {
                                accepted = true;
                                Navigator.of(context).pop();
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryCyan,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade700,
                        disabledForegroundColor: Colors.grey.shade500,
                      ),
                      child: const Text('I Understand & Accept'),
                    ),
                  ],
                ),
          ),
    );

    if (accepted) {
      await markAccepted();
    }

    return accepted;
  }
}
