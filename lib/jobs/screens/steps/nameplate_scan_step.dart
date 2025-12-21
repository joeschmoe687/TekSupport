import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../models/job_step.dart';

class NameplateScanStep extends StatefulWidget {
  final String jobId;
  final JobStep step;
  final Function(Map<String, dynamic>) onComplete;

  const NameplateScanStep({
    super.key,
    required this.jobId,
    required this.step,
    required this.onComplete,
  });

  @override
  State<NameplateScanStep> createState() => _NameplateScanStepState();
}

class _NameplateScanStepState extends State<NameplateScanStep> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  
  bool _hasScanned = false;
  String? _capturedImagePath;

  Future<void> _scanNameplate() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _hasScanned = true;
          _capturedImagePath = image.path;
        });
        // TODO: Implement OCR with google_mlkit_text_recognition
        // For now, prompt manual entry
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo captured. Please verify or enter equipment details.'),
              backgroundColor: AppColors.primaryCyan,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _continue() {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    
    if (brand.isEmpty || model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least brand and model'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onComplete({
      'equipmentBrand': brand,
      'equipmentModel': model,
      'equipmentSerial': _serialController.text.trim(),
      'nameplateImagePath': _capturedImagePath,
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
            Icons.camera_alt,
            size: 64,
            color: AppColors.primaryCyan,
          ),
          const SizedBox(height: 24),
          Text(
            widget.step.title ?? 'Scan Equipment',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.step.description ?? 'Photograph unit nameplates',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _scanNameplate,
            icon: const Icon(Icons.camera),
            label: const Text('Scan Nameplate'),
          ),
          const SizedBox(height: 24),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),
          const Text(
            'Or enter details manually:',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _brandController,
            decoration: const InputDecoration(
              labelText: 'Brand',
              hintText: 'e.g., Carrier, Lennox, Trane',
            ),
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: 'Model Number',
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _serialController,
            decoration: const InputDecoration(
              labelText: 'Serial Number (Optional)',
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 32),
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
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    super.dispose();
  }
}
