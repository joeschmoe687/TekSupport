import 'package:flutter/material.dart';
import '../services/calibration_service.dart';

/// Shows a calibration popup below the tapped reading
/// Allows user to adjust offset with up/down arrows
class CalibrationPopup extends StatefulWidget {
  final String sensorKey;
  final String label;
  final double currentValue;
  final double step;
  final String unit;
  final Color accentColor;
  final VoidCallback onSave;

  const CalibrationPopup({
    super.key,
    required this.sensorKey,
    required this.label,
    required this.currentValue,
    required this.step,
    required this.unit,
    required this.accentColor,
    required this.onSave,
  });

  @override
  State<CalibrationPopup> createState() => _CalibrationPopupState();
}

class _CalibrationPopupState extends State<CalibrationPopup> {
  final CalibrationService _calibrationService = CalibrationService();
  late double _offset;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initOffset();
  }

  Future<void> _initOffset() async {
    await _calibrationService.init();
    setState(() {
      _offset = _calibrationService.getOffset(widget.sensorKey);
      _initialized = true;
    });
  }

  void _adjustOffset(double delta) {
    setState(() {
      _offset += delta;
    });
  }

  Future<void> _saveOffset() async {
    await _calibrationService.setOffset(widget.sensorKey, _offset);
    widget.onSave();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _resetOffset() async {
    await _calibrationService.clearOffset(widget.sensorKey);
    setState(() {
      _offset = 0.0;
    });
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final adjustedValue = widget.currentValue + _offset;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.accentColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calibrate ${widget.label}',
                style: TextStyle(
                  color: widget.accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: Colors.grey, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Current reading display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Down arrow
              _buildArrowButton(
                icon: Icons.remove,
                onTap: () => _adjustOffset(-widget.step),
                onLongPress: () => _adjustOffset(-widget.step * 10),
              ),
              const SizedBox(width: 16),

              // Value display
              Column(
                children: [
                  Text(
                    adjustedValue.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    widget.unit,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  if (_offset != 0)
                    Text(
                      'Offset: ${_offset >= 0 ? '+' : ''}${_offset.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.accentColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Up arrow
              _buildArrowButton(
                icon: Icons.add,
                onTap: () => _adjustOffset(widget.step),
                onLongPress: () => _adjustOffset(widget.step * 10),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Save and Reset buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Reset button
              TextButton(
                onPressed: _resetOffset,
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),

              // Save button
              ElevatedButton(
                onPressed: _saveOffset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

/// Shows calibration popup as an overlay below the tapped widget
void showCalibrationPopup({
  required BuildContext context,
  required GlobalKey targetKey,
  required String sensorKey,
  required String label,
  required double currentValue,
  required double step,
  required String unit,
  required Color accentColor,
  required VoidCallback onSave,
}) {
  final RenderBox? renderBox =
      targetKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return;

  final position = renderBox.localToGlobal(Offset.zero);
  final size = renderBox.size;

  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => Stack(
      children: [
        Positioned(
          left: position.dx - 40, // Center popup under reading
          top: position.dy + size.height + 8,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: size.width + 80,
              child: CalibrationPopup(
                sensorKey: sensorKey,
                label: label,
                currentValue: currentValue,
                step: step,
                unit: unit,
                accentColor: accentColor,
                onSave: onSave,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
