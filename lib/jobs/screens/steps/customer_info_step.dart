import 'package:flutter/material.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../models/job_step.dart';

class CustomerInfoStep extends StatefulWidget {
  final String jobId;
  final JobStep step;
  final Function(Map<String, dynamic>) onComplete;

  const CustomerInfoStep({
    super.key,
    required this.jobId,
    required this.step,
    required this.onComplete,
  });

  @override
  State<CustomerInfoStep> createState() => _CustomerInfoStepState();
}

class _CustomerInfoStepState extends State<CustomerInfoStep> {
  final TextEditingController _nameController = TextEditingController();

  void _continue() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a customer name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onComplete({'customerName': name});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.person,
            size: 64,
            color: AppColors.primaryCyan,
          ),
          const SizedBox(height: 24),
          Text(
            widget.step.title ?? 'Customer Information',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.step.description ?? 'Enter customer or business name',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Customer Name',
              hintText: 'John Smith or ABC Company',
              prefixIcon: Icon(Icons.business, color: AppColors.primaryCyan),
            ),
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
