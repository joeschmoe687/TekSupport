import 'package:flutter/material.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../models/job_step.dart';
import '../../models/equipment.dart';

class SystemTypeStep extends StatefulWidget {
  final String jobId;
  final JobStep step;
  final Function(Map<String, dynamic>) onComplete;

  const SystemTypeStep({
    super.key,
    required this.jobId,
    required this.step,
    required this.onComplete,
  });

  @override
  State<SystemTypeStep> createState() => _SystemTypeStepState();
}

class _SystemTypeStepState extends State<SystemTypeStep> {
  SystemType? _selectedType;

  void _continue() {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a system type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onComplete({'systemType': _selectedType!.name});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.ac_unit,
            size: 64,
            color: AppColors.primaryCyan,
          ),
          const SizedBox(height: 24),
          Text(
            widget.step.title ?? 'System Type',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.step.description ?? 'Select the type of system',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _SystemTypeCard(
            title: 'Air Conditioner',
            description: 'Cooling only system',
            icon: Icons.ac_unit,
            isSelected: _selectedType == SystemType.ac,
            onTap: () => setState(() => _selectedType = SystemType.ac),
          ),
          const SizedBox(height: 16),
          _SystemTypeCard(
            title: 'Heat Pump',
            description: 'Heating and cooling system',
            icon: Icons.heat_pump,
            isSelected: _selectedType == SystemType.heatPump,
            onTap: () => setState(() => _selectedType = SystemType.heatPump),
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

class _SystemTypeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SystemTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? AppColors.primaryCyan.withOpacity(0.2) : AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primaryCyan : AppColors.border.withOpacity(0.3),
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
                color: isSelected ? AppColors.primaryCyan : AppColors.textSecondary,
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
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primaryCyan,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
