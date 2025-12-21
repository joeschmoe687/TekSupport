import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';
import '../models/job.dart';
import '../services/job_service.dart';
import 'job_workflow_screen.dart';

class JobLaunchScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const JobLaunchScreen({super.key, required this.onToggleTheme});

  @override
  State<JobLaunchScreen> createState() => _JobLaunchScreenState();
}

class _JobLaunchScreenState extends State<JobLaunchScreen> {
  final JobService _jobService = JobService();
  bool _isCreating = false;

  Future<void> _launchJob(JobType type) async {
    setState(() => _isCreating = true);

    try {
      final job = await _jobService.createJob(type);

      if (!mounted) return;

      // Navigate to workflow screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JobWorkflowScreen(
            jobId: job.id,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Start a Job'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.work_outline,
                size: 80,
                color: AppColors.primaryCyan,
              ),
              const SizedBox(height: 32),
              const Text(
                'What type of job are you starting?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _JobTypeCard(
                title: 'Commissioning',
                description:
                    'New system installation with full startup procedure',
                icon: Icons.settings_suggest,
                color: AppColors.primaryPurple,
                onTap: _isCreating
                    ? null
                    : () => _launchJob(JobType.commissioning),
              ),
              const SizedBox(height: 16),
              _JobTypeCard(
                title: 'Service Call',
                description: 'Diagnostic and repair on existing system',
                icon: Icons.build_circle,
                color: AppColors.primaryCyan,
                onTap:
                    _isCreating ? null : () => _launchJob(JobType.serviceCall),
              ),
              if (_isCreating) ...[
                const SizedBox(height: 32),
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryCyan,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JobTypeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _JobTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: onTap == null
              ? AppColors.border.withOpacity(0.3)
              : color.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                icon,
                size: 48,
                color: onTap == null ? AppColors.textMuted : color,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: onTap == null ? AppColors.textMuted : Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
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
    );
  }
}
