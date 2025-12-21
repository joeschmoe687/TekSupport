import 'package:flutter/material.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../models/job_step.dart';

class CompletionStep extends StatefulWidget {
  final String jobId;
  final JobStep step;
  final Function(Map<String, dynamic>) onComplete;

  const CompletionStep({
    super.key,
    required this.jobId,
    required this.step,
    required this.onComplete,
  });

  @override
  State<CompletionStep> createState() => _CompletionStepState();
}

class _CompletionStepState extends State<CompletionStep> {
  final TextEditingController _notesController = TextEditingController();

  void _complete() {
    widget.onComplete({
      'completionNotes': _notesController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            widget.step.title ?? 'Complete Job',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.step.description ?? 'Mark this job as complete',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Completion Notes (Optional)',
              hintText: 'Add any final notes or observations...',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.green.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.green, width: 2),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.celebration, color: Colors.green, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Great job!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You\'ve completed all the workflow steps. Your job data has been saved.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _complete,
            icon: const Icon(Icons.check),
            label: const Text('Complete Job'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
