import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Modal dialog for call recording opt-in during signup
/// Explains recording disclosure and captures user consent
class CallRecordingOptInDialog extends StatefulWidget {
  final Function(bool consent) onConsent;

  const CallRecordingOptInDialog({
    super.key,
    required this.onConsent,
  });

  @override
  State<CallRecordingOptInDialog> createState() =>
      _CallRecordingOptInDialogState();
}

class _CallRecordingOptInDialogState extends State<CallRecordingOptInDialog> {
  bool hasConsent = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Call Recording Disclosure'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Would you like to allow call recording?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '📞 Important Information:\n\n'
                '• We may record calls for quality assurance and training purposes.\n'
                '• You will hear a voice notice before recording begins.\n'
                '• Recordings are stored securely and kept indefinitely.\n'
                '• Only admins can access recordings.\n'
                '• You can change this setting anytime in app settings.\n\n'
                'By selecting "I Agree," you consent to call recording as permitted by law in your location.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: hasConsent,
                  onChanged: (value) {
                    setState(() => hasConsent = value ?? false);
                  },
                ),
                const Expanded(
                  child: Text(
                    'I understand and consent to call recording',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onConsent(false);
            Navigator.of(context).pop();
          },
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: hasConsent
              ? () {
                  widget.onConsent(true);
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('I Agree'),
        ),
      ],
    );
  }
}

/// Show call recording opt-in dialog
/// Called during signup flow
Future<bool?> showCallRecordingOptIn(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => CallRecordingOptInDialog(
      onConsent: (consent) {
        Navigator.of(context).pop(consent);
      },
    ),
  );
}

/// Save call recording consent to Firestore
/// Called after user completes signup
Future<void> saveCallRecordingConsent(String userId, bool consent) async {
  try {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'callRecordingConsent': consent,
      'callRecordingConsentUpdatedAt': FieldValue.serverTimestamp(),
    }).then((_) {
      print('Call recording consent saved: $consent');
    });
  } catch (e) {
    print('Error saving call recording consent: $e');
  }
}

/// Get user's call recording consent status
Future<bool> getUserCallRecordingConsent(String userId) async {
  try {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    return doc.data()?['callRecordingConsent'] as bool? ?? false;
  } catch (e) {
    print('Error getting call recording consent: $e');
    return false;
  }
}
