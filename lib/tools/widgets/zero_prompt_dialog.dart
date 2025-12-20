import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';

/// Dialog to prompt user to zero their gauges before connecting to equipment.
/// Only shown when gauges have no pressure (near 0 psig).
class ZeroPromptDialog extends StatelessWidget {
  final String deviceName;
  final double currentHighSide;
  final double currentLowSide;
  final VoidCallback onZeroed;
  final VoidCallback? onSkip;

  const ZeroPromptDialog({
    super.key,
    required this.deviceName,
    required this.currentHighSide,
    required this.currentLowSide,
    required this.onZeroed,
    this.onSkip,
  });

  /// Show the zero prompt dialog
  static Future<bool> show(
    BuildContext context, {
    required String deviceName,
    required double currentHighSide,
    required double currentLowSide,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ZeroPromptDialog(
        deviceName: deviceName,
        currentHighSide: currentHighSide,
        currentLowSide: currentLowSide,
        onZeroed: () => Navigator.of(context).pop(true),
        onSkip: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceDark,
              AppColors.background,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryCyan.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryCyan.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.buttonGradient,
                ),
                child: const Icon(
                  Icons.speed,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Zero Your Gauges',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'Before connecting to the system, make sure your gauges are zeroed for accurate readings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              // Current readings display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildReadingColumn(
                      'High Side',
                      '${currentHighSide.toStringAsFixed(1)} psig',
                      AppColors.error,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.border,
                    ),
                    _buildReadingColumn(
                      'Low Side',
                      '${currentLowSide.toStringAsFixed(1)} psig',
                      AppColors.primaryCyan,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Instruction
              Text(
                'These readings will be used as zero offset',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),

              // Zeroed button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onZeroed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ).copyWith(
                    backgroundColor:
                        WidgetStateProperty.all(Colors.transparent),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Zeroed ✓',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Skip button (optional)
              if (onSkip != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
