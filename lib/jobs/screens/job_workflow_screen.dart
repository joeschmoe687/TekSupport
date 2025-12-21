import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';
import '../models/job.dart';
import '../models/job_step.dart';
import '../services/job_service.dart';
import 'steps/location_capture_step.dart';
import 'steps/customer_info_step.dart';
import 'steps/system_type_step.dart';
import 'steps/nameplate_scan_step.dart';
import 'steps/mode_selection_step.dart';
import 'steps/gauge_connection_step.dart';
import 'steps/stabilization_step.dart';
import 'steps/amp_draw_step.dart';
import 'steps/diagnostics_step.dart';
import 'steps/completion_step.dart';

class JobWorkflowScreen extends StatefulWidget {
  final String jobId;
  final VoidCallback onToggleTheme;

  const JobWorkflowScreen({
    super.key,
    required this.jobId,
    required this.onToggleTheme,
  });

  @override
  State<JobWorkflowScreen> createState() => _JobWorkflowScreenState();
}

class _JobWorkflowScreenState extends State<JobWorkflowScreen> {
  final JobService _jobService = JobService();
  Job? _job;

  @override
  void initState() {
    super.initState();
    _loadJobData();
  }

  Future<void> _loadJobData() async {
    final job = await _jobService.getJob(widget.jobId);
    if (mounted && job != null) {
      setState(() => _job = job);
    }
  }

  Future<void> _onStepComplete(JobStep step, Map<String, dynamic>? data) async {
    // Update step status
    await _jobService.completeJobStep(step.id);

    // Update job with step data if provided
    if (data != null && _job != null) {
      final updatedMetadata = Map<String, dynamic>.from(_job!.metadata ?? {});
      updatedMetadata.addAll(data);
      final updatedJob = _job!.copyWith(metadata: updatedMetadata);
      await _jobService.updateJob(updatedJob);
      if (mounted) {
        setState(() => _job = updatedJob);
      }
    }
  }

  Widget _buildStepWidget(JobStep step) {
    switch (step.type) {
      case StepType.locationCapture:
        return LocationCaptureStep(
          jobId: widget.jobId,
          step: step,
          onComplete: (data) => _onStepComplete(step, data),
        );
      case StepType.customerInfo:
        return CustomerInfoStep(
          jobId: widget.jobId,
          step: step,
          onComplete: (data) => _onStepComplete(step, data),
        );
      case StepType.systemTypeSelection:
        return SystemTypeStep(
          jobId: widget.jobId,
          step: step,
          onComplete: (data) => _onStepComplete(step, data),
        );
      case StepType.nameplateOcr:
        return NameplateScanStep(
          jobId: widget.jobId,
          step: step,
          onComplete: (data) => _onStepComplete(step, data),
        );
      case StepType.modeSelection:
        return ModeSelectionStep(
          jobId: widget.jobId,
          step: step,
          onComplete: (data) => _onStepComplete(step, data),
        );
      case StepType.gaugeConnection:
        return GaugeConnectionStep(
          jobId: widget.jobId,
          step: step,
          onComplete: (data) => _onStepComplete(step, data),
          onToggleTheme: widget.onToggleTheme,
        );
      case StepType.stabilization:
        return StabilizationStep(
          jobId: widget.jobId,
          step: step,
          onComplete: (data) => _onStepComplete(step, data),
        );
      case StepType.ampDrawMeasurement:
        return AmpDrawStep(
          jobId: widget.jobId,
          step: step,
          onComplete: (data) => _onStepComplete(step, data),
        );
      case StepType.diagnostics:
        return DiagnosticsStep(
          jobId: widget.jobId,
          step: step,
          job: _job,
          onComplete: (data) => _onStepComplete(step, data),
          onToggleTheme: widget.onToggleTheme,
        );
      case StepType.completion:
        return CompletionStep(
          jobId: widget.jobId,
          step: step,
          onComplete: (data) async {
            // Save completion notes if provided
            if (data != null && _job != null) {
              final updatedMetadata = Map<String, dynamic>.from(_job!.metadata ?? {});
              updatedMetadata.addAll(data);
              final updatedJob = _job!.copyWith(metadata: updatedMetadata);
              await _jobService.updateJob(updatedJob);
            }
            
            await _jobService.completeJob(widget.jobId);
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      default:
        return const Center(child: Text('Unknown step type'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: Text(_job?.type == JobType.commissioning
            ? 'Commissioning Job'
            : 'Service Call'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<JobStep>>(
        stream: _jobService.getJobSteps(widget.jobId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryCyan),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading job steps: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final steps = snapshot.data ?? [];
          if (steps.isEmpty) {
            return const Center(
              child: Text('No steps found'),
            );
          }

          // Find current step (first incomplete step)
          final currentStepIndex = () {
            final index = steps.indexWhere(
              (s) => s.status != StepStatus.completed && s.status != StepStatus.skipped,
            );
            if (index == -1) {
              return steps.length - 1; // All done, show last step
            }
            return index;
          }();

          final currentStep = steps[currentStepIndex];

          return Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(steps, currentStepIndex),
              
              // Current step content
              Expanded(
                child: _buildStepWidget(currentStep),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator(List<JobStep> steps, int currentIndex) {
    final completedSteps = steps.where((s) => s.status == StepStatus.completed).length;
    final totalSteps = steps.length;
    final progress = completedSteps / totalSteps;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withOpacity(0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${currentIndex + 1} of $totalSteps',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}% Complete',
                style: const TextStyle(
                  color: AppColors.primaryCyan,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryCyan),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
