import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';
import '../services/refrigerant_detector.dart';

/// Dialog to confirm refrigerant type, especially for R22 systems
/// that may have been converted to drop-in refrigerants.
class RefrigerantConfirmDialog extends StatelessWidget {
  final Refrigerant suggestedRefrigerant;
  final List<Refrigerant> alternatives;
  final double? highSidePressure;
  final double? lowSidePressure;
  final ValueChanged<Refrigerant> onSelected;

  const RefrigerantConfirmDialog({
    super.key,
    required this.suggestedRefrigerant,
    required this.alternatives,
    this.highSidePressure,
    this.lowSidePressure,
    required this.onSelected,
  });

  /// Show the refrigerant confirmation dialog
  static Future<Refrigerant?> show(
    BuildContext context, {
    required Refrigerant suggestedRefrigerant,
    required List<Refrigerant> alternatives,
    double? highSidePressure,
    double? lowSidePressure,
  }) async {
    return await showDialog<Refrigerant>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RefrigerantConfirmDialog(
        suggestedRefrigerant: suggestedRefrigerant,
        alternatives: alternatives,
        highSidePressure: highSidePressure,
        lowSidePressure: lowSidePressure,
        onSelected: (refrigerant) => Navigator.of(context).pop(refrigerant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build list with suggested first, then alternatives
    final allOptions = [suggestedRefrigerant, ...alternatives];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
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
              // Icon with refrigerant symbol
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.buttonGradient,
                ),
                child: const Icon(
                  Icons.thermostat,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Confirm Refrigerant Type',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Is this system '),
                    TextSpan(
                      text: suggestedRefrigerant.displayName,
                      style: TextStyle(
                        color: AppColors.primaryCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' or a drop-in replacement?'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Helpful note for R22
              if (suggestedRefrigerant == Refrigerant.r22)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Check for stickers or sharpie notes indicating a refrigerant swap.',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Pressure readings if available
              if (highSidePressure != null && lowSidePressure != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPressureChip(
                          'High', highSidePressure!, AppColors.error),
                      _buildPressureChip(
                          'Low', lowSidePressure!, AppColors.primaryCyan),
                    ],
                  ),
                ),

              // Refrigerant options
              ...allOptions.map((refrigerant) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildRefrigerantButton(
                      refrigerant: refrigerant,
                      isPrimary: refrigerant == suggestedRefrigerant,
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefrigerantButton({
    required Refrigerant refrigerant,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => onSelected(refrigerant),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor:
              isPrimary ? Colors.transparent : AppColors.surfaceLight,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isPrimary
                ? BorderSide.none
                : BorderSide(color: AppColors.border),
          ),
        ),
        child: isPrimary
            ? Ink(
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    refrigerant.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : Text(
                refrigerant.displayName,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Widget _buildPressureChip(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(0)} psig',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Quick selection chip for common refrigerants in settings
class RefrigerantChip extends StatelessWidget {
  final Refrigerant refrigerant;
  final bool isSelected;
  final VoidCallback onTap;

  const RefrigerantChip({
    super.key,
    required this.refrigerant,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.buttonGradient : null,
          color: isSelected ? null : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          refrigerant.displayName,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
