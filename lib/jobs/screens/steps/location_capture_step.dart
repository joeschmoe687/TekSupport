import 'package:flutter/material.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../models/job_step.dart';
import '../../services/location_service.dart';

class LocationCaptureStep extends StatefulWidget {
  final String jobId;
  final JobStep step;
  final Function(Map<String, dynamic>) onComplete;

  const LocationCaptureStep({
    super.key,
    required this.jobId,
    required this.step,
    required this.onComplete,
  });

  @override
  State<LocationCaptureStep> createState() => _LocationCaptureStepState();
}

class _LocationCaptureStepState extends State<LocationCaptureStep> {
  final LocationService _locationService = LocationService();
  final TextEditingController _addressController = TextEditingController();
  
  bool _isLoading = false;
  String? _detectedAddress;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    setState(() => _isLoading = true);

    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        _latitude = position.latitude;
        _longitude = position.longitude;

        final address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (mounted) {
          setState(() {
            _detectedAddress = address;
            _addressController.text = address ?? '';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error detecting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _continue() {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onComplete({
      'locationAddress': address,
      'latitude': _latitude,
      'longitude': _longitude,
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
            Icons.location_on,
            size: 64,
            color: AppColors.primaryCyan,
          ),
          const SizedBox(height: 24),
          Text(
            widget.step.title ?? 'Capture Location',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.step.description ?? 'Auto-detect job location using GPS',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryCyan),
            )
          else ...[
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Job Location',
                hintText: 'Enter address',
                prefixIcon: Icon(Icons.home, color: AppColors.primaryCyan),
              ),
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _detectLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Detect Location Again'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _continue,
              child: const Text('Continue'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }
}
