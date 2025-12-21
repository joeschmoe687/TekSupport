import 'package:flutter/material.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../tools/screens/devices_screen.dart';
import '../../models/job_step.dart';

class GaugeConnectionStep extends StatefulWidget {
  final String jobId;
  final JobStep step;
  final Function(Map<String, dynamic>) onComplete;

  const GaugeConnectionStep({
    super.key,
    required this.jobId,
    required this.step,
    required this.onComplete,
  });

  @override
  State<GaugeConnectionStep> createState() => _GaugeConnectionStepState();
}

class _GaugeConnectionStepState extends State<GaugeConnectionStep> {
  void _openDevices() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DevicesScreen(onToggleTheme: () {}),
      ),
    ).then((_) {
      // User returned from devices screen
    });
  }

  void _continue() {
    widget.onComplete({});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.speed,
            size: 64,
            color: AppColors.primaryCyan,
          ),
          const SizedBox(height: 24),
          Text(
            widget.step.title ?? 'Connect Gauges',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.step.description ?? 'Connect pressure gauges and temperature probes',
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
                    'Connection Steps:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InstructionItem(
                    number: '1',
                    text: 'Connect manifold gauges to service ports',
                  ),
                  _InstructionItem(
                    number: '2',
                    text: 'Attach temperature clamps to suction and liquid lines',
                  ),
                  _InstructionItem(
                    number: '3',
                    text: 'Power on your Bluetooth tools',
                  ),
                  _InstructionItem(
                    number: '4',
                    text: 'Connect devices using the button below',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openDevices,
            icon: const Icon(Icons.bluetooth),
            label: const Text('Connect Devices'),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _continue,
            child: const Text('Continue Without Devices'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _continue,
            child: const Text('Devices Connected - Continue'),
          ),
        ],
      ),
    );
  }
}

class _InstructionItem extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionItem({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primaryCyan,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
