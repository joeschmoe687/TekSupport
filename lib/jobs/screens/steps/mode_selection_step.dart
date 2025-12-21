import 'package:flutter/material.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../models/job_step.dart';

class ModeSelectionStep extends StatefulWidget {
  final String jobId;
  final JobStep step;
  final Function(Map<String, dynamic>) onComplete;

  const ModeSelectionStep({
    super.key,
    required this.jobId,
    required this.step,
    required this.onComplete,
  });

  @override
  State<ModeSelectionStep> createState() => _ModeSelectionStepState();
}

class _ModeSelectionStepState extends State<ModeSelectionStep> {
  String? _selectedMode;

  void _continue() {
    if (_selectedMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a mode'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onComplete({'systemMode': _selectedMode});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.thermostat,
            size: 64,
            color: AppColors.primaryCyan,
          ),
          const SizedBox(height: 24),
          Text(
            widget.step.title ?? 'System Mode',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.step.description ?? 'Start the system in the appropriate mode',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _ModeCard(
            title: 'Cooling Mode',
            description: 'Test air conditioning performance',
            icon: Icons.ac_unit,
            color: Colors.blue,
            isSelected: _selectedMode == 'cooling',
            onTap: () => setState(() => _selectedMode = 'cooling'),
          ),
          const SizedBox(height: 16),
          _ModeCard(
            title: 'Heating Mode',
            description: 'Test heating performance',
            icon: Icons.local_fire_department,
            color: Colors.red,
            isSelected: _selectedMode == 'heating',
            onTap: () => setState(() => _selectedMode = 'heating'),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _continue,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? color.withOpacity(0.2) : AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : AppColors.border.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 40,
                color: isSelected ? color : AppColors.textSecondary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: color,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
