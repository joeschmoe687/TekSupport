import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';
import '../services/diagnostic_engine.dart';

/// Bottom sheet showing step-by-step troubleshooting guidance
class TroubleshootingSheet extends StatefulWidget {
  final DiagnosticResult diagnostic;

  const TroubleshootingSheet({
    super.key,
    required this.diagnostic,
  });

  static Future<void> show(BuildContext context, DiagnosticResult diagnostic) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TroubleshootingSheet(diagnostic: diagnostic),
    );
  }

  @override
  State<TroubleshootingSheet> createState() => _TroubleshootingSheetState();
}

class _TroubleshootingSheetState extends State<TroubleshootingSheet> {
  bool _isBeginnerMode = true;
  final Set<int> _completedSteps = {};

  @override
  Widget build(BuildContext context) {
    final steps = _generateTroubleshootingSteps();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.build_circle,
                  color: AppColors.primaryCyan,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Troubleshooting Guide',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Mode toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isBeginnerMode ? Icons.school : Icons.engineering,
                        color: AppColors.primaryCyan,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isBeginnerMode = !_isBeginnerMode;
                          });
                        },
                        child: Text(
                          _isBeginnerMode ? 'Beginner' : 'Expert',
                          style: const TextStyle(
                            color: AppColors.primaryCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // Steps
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: steps.length,
              itemBuilder: (context, index) {
                return _buildStepCard(index + 1, steps[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(int stepNumber, TroubleshootingStep step) {
    final isCompleted = _completedSteps.contains(stepNumber);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.success.withOpacity(0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withOpacity(0.3)
              : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: GestureDetector(
            onTap: () {
              setState(() {
                if (isCompleted) {
                  _completedSteps.remove(stepNumber);
                } else {
                  _completedSteps.add(stepNumber);
                }
              });
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success
                    : AppColors.primaryCyan.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted
                      ? AppColors.success
                      : AppColors.primaryCyan,
                  width: 2,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 18,
                      )
                    : Text(
                        stepNumber.toString(),
                        style: const TextStyle(
                          color: AppColors.primaryCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ),
          title: Text(
            step.title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: _isBeginnerMode && step.beginnerTip != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    step.beginnerTip!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                )
              : null,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (step.caution != null) ...[
                    const SizedBox(height: 12),
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
                          const Icon(
                            Icons.warning_amber,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step.caution!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TroubleshootingStep> _generateTroubleshootingSteps() {
    // Analyze the diagnostic to determine which troubleshooting path
    final alerts = widget.diagnostic.alerts;

    // Check for low charge pattern
    final hasLowSuperheat = alerts.any((a) =>
        a.type == AlertType.superheat &&
        a.message.contains('HIGH'));
    final hasLowSubcool = alerts.any((a) =>
        a.type == AlertType.subcool &&
        a.message.contains('LOW'));

    if (hasLowSuperheat && hasLowSubcool) {
      return _getLowChargeSteps();
    }

    // Check for overcharge pattern
    final hasHighSubcool = alerts.any((a) =>
        a.type == AlertType.subcool &&
        a.message.contains('HIGH'));
    
    if (hasHighSubcool) {
      return _getOverchargeSteps();
    }

    // Check for TXV issues
    final hasLowSuperheatValue = alerts.any((a) =>
        a.type == AlertType.superheat &&
        a.message.contains('LOW'));

    if (hasLowSuperheatValue) {
      return _getTxvFloodingSteps();
    }

    // Default general troubleshooting
    return _getGeneralTroubleshootingSteps();
  }

  List<TroubleshootingStep> _getLowChargeSteps() {
    return [
      TroubleshootingStep(
        title: 'Verify low charge symptoms',
        description: 'Confirm that both superheat is high (>15°F) and subcool is low (<5°F). This combination strongly indicates low refrigerant charge.',
        beginnerTip: 'Superheat and subcool are calculated automatically from your gauge readings',
      ),
      TroubleshootingStep(
        title: 'Check for leaks',
        description: 'Use a leak detector or bubble solution to check common leak points: service ports, flare connections, brazed joints, and evaporator coil.',
        beginnerTip: 'Start with service ports - they\'re the most common leak source',
        caution: 'Always repair leaks before adding refrigerant',
      ),
      TroubleshootingStep(
        title: 'Recover and weigh charge (if needed)',
        description: 'If system is severely undercharged, recover remaining refrigerant, repair leak, evacuate system, and charge by weight per nameplate.',
        beginnerTip: 'Nameplate shows exact charge amount - usually on outdoor unit',
      ),
      TroubleshootingStep(
        title: 'Add refrigerant slowly',
        description: 'Add small amounts of refrigerant while monitoring pressures and subcool. Target 10-12°F subcool for most systems.',
        caution: 'Add refrigerant in vapor form on suction side, or liquid on high side with unit off',
      ),
      TroubleshootingStep(
        title: 'Verify final readings',
        description: 'After charging, verify all readings are within normal range: pressures, superheat (10-15°F), and subcool (8-12°F).',
      ),
    ];
  }

  List<TroubleshootingStep> _getOverchargeSteps() {
    return [
      TroubleshootingStep(
        title: 'Verify overcharge symptoms',
        description: 'Confirm high subcool (>15°F), high discharge pressure, and possibly low superheat. These indicate too much refrigerant.',
        beginnerTip: 'Overcharge can damage compressor - address promptly',
      ),
      TroubleshootingStep(
        title: 'Recover excess refrigerant',
        description: 'Use recovery machine to remove refrigerant until subcool reaches target range (8-12°F for most systems).',
        caution: 'Never vent refrigerant to atmosphere - it\'s illegal and harmful',
      ),
      TroubleshootingStep(
        title: 'Monitor while recovering',
        description: 'Watch subcool reading drop as you remove refrigerant. Stop when subcool reaches 10-12°F.',
        beginnerTip: 'Remove refrigerant slowly to avoid overshooting target',
      ),
      TroubleshootingStep(
        title: 'Check for other issues',
        description: 'High readings can also be caused by condenser problems. Check condenser coil cleanliness and fan operation.',
      ),
    ];
  }

  List<TroubleshootingStep> _getTxvFloodingSteps() {
    return [
      TroubleshootingStep(
        title: 'Verify TXV flooding',
        description: 'Confirm low superheat (<5°F) with higher than normal suction pressure. This indicates TXV is allowing too much refrigerant.',
        beginnerTip: 'TXV = Thermostatic Expansion Valve - it meters refrigerant into evaporator',
        caution: 'Low superheat can cause liquid floodback and damage compressor',
      ),
      TroubleshootingStep(
        title: 'Check sensing bulb',
        description: 'Ensure TXV sensing bulb is properly secured to suction line with good thermal contact. Remove any insulation around bulb area.',
        beginnerTip: 'Sensing bulb should be at 4 or 8 o\'clock position on horizontal suction line',
      ),
      TroubleshootingStep(
        title: 'Check TXV adjustment',
        description: 'If TXV is adjustable, turn adjustment stem clockwise (in) to reduce refrigerant flow and increase superheat.',
        beginnerTip: 'Make small 1/4 turn adjustments and wait 10-15 minutes between adjustments',
      ),
      TroubleshootingStep(
        title: 'Consider TXV replacement',
        description: 'If adjustments don\'t help, TXV may be stuck open or damaged. Replace with correct size TXV per manufacturer specs.',
      ),
    ];
  }

  List<TroubleshootingStep> _getGeneralTroubleshootingSteps() {
    return [
      TroubleshootingStep(
        title: 'Document current readings',
        description: 'Record all current pressures, temperatures, superheat, and subcool values before making any changes.',
      ),
      TroubleshootingStep(
        title: 'Check basics first',
        description: 'Verify indoor air filter is clean, all registers are open, outdoor unit has clear airflow, and both fan motors are running.',
        beginnerTip: 'Many HVAC problems are caused by simple airflow issues',
      ),
      TroubleshootingStep(
        title: 'Compare to expected values',
        description: 'Use the expected ranges shown in the diagnostic to identify which readings are out of spec.',
      ),
      TroubleshootingStep(
        title: 'Address root cause',
        description: 'Based on the specific alerts, follow the recommended troubleshooting steps for each issue.',
      ),
      TroubleshootingStep(
        title: 'Recheck after fixes',
        description: 'After making adjustments, allow system to stabilize for 10-15 minutes then verify all readings are normal.',
      ),
    ];
  }
}

/// Individual troubleshooting step
class TroubleshootingStep {
  final String title;
  final String description;
  final String? beginnerTip;
  final String? caution;

  TroubleshootingStep({
    required this.title,
    required this.description,
    this.beginnerTip,
    this.caution,
  });
}
