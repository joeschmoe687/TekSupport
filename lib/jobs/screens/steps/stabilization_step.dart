import 'package:flutter/material.dart';
import 'dart:async';
import '../../../widgets/gradient_scaffold.dart';
import '../../models/job_step.dart';

class StabilizationStep extends StatefulWidget {
  final String jobId;
  final JobStep step;
  final Function(Map<String, dynamic>) onComplete;

  const StabilizationStep({
    super.key,
    required this.jobId,
    required this.step,
    required this.onComplete,
  });

  @override
  State<StabilizationStep> createState() => _StabilizationStepState();
}

class _StabilizationStepState extends State<StabilizationStep> {
  static const int stabilizationMinutes = 20;
  late DateTime _endTime;
  Timer? _timer;
  Duration _remaining = const Duration(minutes: stabilizationMinutes);

  @override
  void initState() {
    super.initState();
    // TODO: Persist stabilization start time to job metadata for app restart recovery
    // For now, timer restarts if user navigates away
    _endTime = DateTime.now().add(const Duration(minutes: stabilizationMinutes));
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (now.isAfter(_endTime)) {
        setState(() {
          _remaining = Duration.zero;
        });
        timer.cancel();
      } else {
        setState(() {
          _remaining = _endTime.difference(now);
        });
      }
    });
  }

  void _skipWithWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Skip Stabilization?', style: TextStyle(color: Colors.white)),
        content: Text(
          'The system may not have stabilized yet. Readings may be inaccurate. Are you sure you want to continue?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete({'skippedStabilization': true});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Skip Anyway'),
          ),
        ],
      ),
    );
  }

  void _continue() {
    widget.onComplete({'stabilizationComplete': true});
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    final isComplete = _remaining == Duration.zero;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            isComplete ? Icons.check_circle : Icons.schedule,
            size: 64,
            color: isComplete ? Colors.green : AppColors.primaryCyan,
          ),
          const SizedBox(height: 24),
          Text(
            widget.step.title ?? 'System Stabilization',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isComplete
                ? 'System has stabilized!'
                : '${widget.step.description ?? "20-minute stabilization period"}',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isComplete ? Colors.green : AppColors.primaryCyan,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  isComplete ? 'Complete!' : 'Time Remaining',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isComplete
                      ? '✓'
                      : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: isComplete ? Colors.green : AppColors.primaryCyan,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Card(
            color: AppColors.surfaceDark.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primaryCyan, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Why wait?',
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
                    'TXV systems need time to stabilize for accurate readings. Use this time to check electrical connections, inspect ductwork, or review the installation.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (!isComplete) ...[
            OutlinedButton(
              onPressed: _skipWithWarning,
              child: const Text('Skip Stabilization'),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: isComplete ? _continue : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
    }
    super.dispose();
  }
}
