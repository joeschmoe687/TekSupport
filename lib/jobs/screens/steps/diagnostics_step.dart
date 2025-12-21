import 'package:flutter/material.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../tools/screens/tools_hub_screen.dart';
import '../../models/job.dart';
import '../../models/job_step.dart';

class DiagnosticsStep extends StatefulWidget {
  final String jobId;
  final JobStep step;
  final Job? job;
  final Function(Map<String, dynamic>) onComplete;
  final VoidCallback onToggleTheme;

  const DiagnosticsStep({
    super.key,
    required this.jobId,
    required this.step,
    this.job,
    required this.onComplete,
    required this.onToggleTheme,
  });

  @override
  State<DiagnosticsStep> createState() => _DiagnosticsStepState();
}

class _DiagnosticsStepState extends State<DiagnosticsStep> {
  void _openTools() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ToolsHubScreen(onToggleTheme: widget.onToggleTheme),
      ),
    );
  }

  void _continue() {
    widget.onComplete({});
  }

  @override
  Widget build(BuildContext context) {
    final isServiceCall = widget.job?.type == JobType.serviceCall;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.analytics,
            size: 64,
            color: AppColors.primaryCyan,
          ),
          const SizedBox(height: 24),
          Text(
            widget.step.title ?? 'System Diagnostics',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isServiceCall
                ? 'Use TekTool to diagnose the system issue'
                : widget.step.description ?? 'Review readings and adjust as needed',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Card(
            color: AppColors.surfaceDark,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What to Check:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CheckItem(text: 'Superheat and subcooling values'),
                  _CheckItem(text: 'System pressures vs. targets'),
                  _CheckItem(text: 'Temperature differential across coils'),
                  if (!isServiceCall) ...[
                    _CheckItem(text: 'Refrigerant charge level'),
                    _CheckItem(text: 'Airflow and static pressure'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openTools,
            icon: const Icon(Icons.build),
            label: const Text('Open TekTool'),
          ),
          if (!isServiceCall) ...[
            const SizedBox(height: 32),
            Card(
              color: AppColors.surfaceDark.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primaryCyan, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Commissioning Tips',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Target superheat: 8-12°F for TXV systems\n'
                      '• Target subcooling: 10-15°F\n'
                      '• Verify refrigerant charge after system stabilizes\n'
                      '• Document all readings for warranty purposes',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          ElevatedButton(
            onPressed: _continue,
            child: Text(isServiceCall ? 'Complete Service Call' : 'Continue to Complete'),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;

  const _CheckItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 20,
            color: AppColors.primaryCyan,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
