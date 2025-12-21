import 'package:flutter/material.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../models/job_step.dart';

class AmpDrawStep extends StatefulWidget {
  final String jobId;
  final JobStep step;
  final Function(Map<String, dynamic>) onComplete;

  const AmpDrawStep({
    super.key,
    required this.jobId,
    required this.step,
    required this.onComplete,
  });

  @override
  State<AmpDrawStep> createState() => _AmpDrawStepState();
}

class _AmpDrawStepState extends State<AmpDrawStep> {
  final TextEditingController _blowerAmpsController = TextEditingController();
  final TextEditingController _fanAmpsController = TextEditingController();
  final TextEditingController _compressorAmpsController = TextEditingController();

  void _continue() {
    final blowerAmps = double.tryParse(_blowerAmpsController.text);
    final fanAmps = double.tryParse(_fanAmpsController.text);
    final compressorAmps = double.tryParse(_compressorAmpsController.text);

    if (blowerAmps == null || fanAmps == null || compressorAmps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all amp draw measurements'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onComplete({
      'blowerAmps': blowerAmps,
      'fanAmps': fanAmps,
      'compressorAmps': compressorAmps,
    });
  }

  void _skip() {
    widget.onComplete({});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.electrical_services,
            size: 64,
            color: AppColors.primaryCyan,
          ),
          const SizedBox(height: 24),
          Text(
            widget.step.title ?? 'Amp Draw Readings',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.step.description ?? 'Measure motor amp draws',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _blowerAmpsController,
            decoration: const InputDecoration(
              labelText: 'Blower Motor Amps',
              hintText: '0.0',
              suffixText: 'A',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _fanAmpsController,
            decoration: const InputDecoration(
              labelText: 'Condenser Fan Motor Amps',
              hintText: '0.0',
              suffixText: 'A',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _compressorAmpsController,
            decoration: const InputDecoration(
              labelText: 'Compressor Amps',
              hintText: '0.0',
              suffixText: 'A',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
          ),
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
                      Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tip',
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
                    'Use an amp clamp meter on each wire. Compare to nameplate RLA/FLA ratings for troubleshooting.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _continue,
            child: const Text('Continue'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _skip,
            child: const Text('Skip for Now'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _blowerAmpsController.dispose();
    _fanAmpsController.dispose();
    _compressorAmpsController.dispose();
    super.dispose();
  }
}
