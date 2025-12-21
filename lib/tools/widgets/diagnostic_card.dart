import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';
import '../services/diagnostic_engine.dart';
import '../services/hvac_knowledge_base.dart';

/// Card widget showing current diagnostic status with recommendations
class DiagnosticCard extends StatelessWidget {
  final DiagnosticResult diagnostic;
  final VoidCallback? onTroubleshootTap;

  const DiagnosticCard({
    super.key,
    required this.diagnostic,
    this.onTroubleshootTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!diagnostic.hasIssues) {
      return _buildNormalCard(context);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getCardColor(diagnostic.overallStatus),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor(diagnostic.overallStatus),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _getBorderColor(diagnostic.overallStatus).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getBorderColor(diagnostic.overallStatus).withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(diagnostic.overallStatus),
                  color: _getBorderColor(diagnostic.overallStatus),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getStatusTitle(diagnostic.overallStatus),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onTroubleshootTap != null)
                  TextButton.icon(
                    onPressed: onTroubleshootTap,
                    icon: const Icon(Icons.build, size: 18),
                    label: const Text('Fix'),
                    style: TextButton.styleFrom(
                      foregroundColor: _getBorderColor(diagnostic.overallStatus),
                    ),
                  ),
              ],
            ),
          ),

          // Alerts
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Combined diagnostic (if available)
                if (diagnostic.combinedDiagnostic != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.info.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb, color: AppColors.info, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            diagnostic.combinedDiagnostic!,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Individual alerts
                ...diagnostic.alerts.map((alert) => _buildAlertItem(alert)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'System readings are within normal range',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(DiagnosticAlert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alert message
          Text(
            alert.message,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          
          // Possible causes
          Text(
            'Possible causes:',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...alert.possibleCauses.take(3).map((cause) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        cause,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Color _getCardColor(ReadingStatus status) {
    switch (status) {
      case ReadingStatus.critical:
        return AppColors.error.withOpacity(0.1);
      case ReadingStatus.warning:
        return AppColors.warning.withOpacity(0.1);
      case ReadingStatus.normal:
        return AppColors.success.withOpacity(0.1);
    }
  }

  Color _getBorderColor(ReadingStatus status) {
    switch (status) {
      case ReadingStatus.critical:
        return AppColors.error;
      case ReadingStatus.warning:
        return AppColors.warning;
      case ReadingStatus.normal:
        return AppColors.success;
    }
  }

  IconData _getStatusIcon(ReadingStatus status) {
    switch (status) {
      case ReadingStatus.critical:
        return Icons.error;
      case ReadingStatus.warning:
        return Icons.warning;
      case ReadingStatus.normal:
        return Icons.check_circle;
    }
  }

  String _getStatusTitle(ReadingStatus status) {
    switch (status) {
      case ReadingStatus.critical:
        return 'Critical Issue Detected';
      case ReadingStatus.warning:
        return 'Warning - Needs Attention';
      case ReadingStatus.normal:
        return 'System Normal';
    }
  }
}
