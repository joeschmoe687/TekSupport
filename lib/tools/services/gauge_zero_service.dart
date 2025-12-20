import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage gauge zeroing for accurate pressure readings.
/// Prompts user to zero gauges when they show no pressure (disconnected from system).
class GaugeZeroService {
  static final GaugeZeroService _instance = GaugeZeroService._internal();
  factory GaugeZeroService() => _instance;
  GaugeZeroService._internal();

  // Threshold for determining if gauges have pressure (in psig)
  // If reading is within this range of 0, consider it "no pressure"
  static const double zeroPressureThreshold = 5.0;

  // Zero offsets stored per device
  final Map<String, GaugeZeroOffset> _zeroOffsets = {};

  // Stream to notify when zeroing is needed
  final _zeroNeededController = StreamController<ZeroPromptData>.broadcast();
  Stream<ZeroPromptData> get onZeroNeeded => _zeroNeededController.stream;

  /// Check if a pressure reading indicates the gauge is connected to a live system
  /// or if it's near zero (ready to be zeroed)
  bool hasPressure(double reading) {
    return reading.abs() > zeroPressureThreshold;
  }

  /// Called when a gauge device connects.
  /// Returns true if zeroing prompt should be shown.
  bool shouldPromptForZero({
    required String deviceId,
    required double highSideReading,
    required double lowSideReading,
  }) {
    // If either gauge has significant pressure, skip zeroing
    // (device reconnected mid-job with system pressure)
    if (hasPressure(highSideReading) || hasPressure(lowSideReading)) {
      return false;
    }

    // No pressure detected - should zero before connecting to system
    return true;
  }

  /// Record zero offset for a device
  void setZeroOffset({
    required String deviceId,
    required double highSideOffset,
    required double lowSideOffset,
  }) {
    _zeroOffsets[deviceId] = GaugeZeroOffset(
      deviceId: deviceId,
      highSideOffset: highSideOffset,
      lowSideOffset: lowSideOffset,
      zeroedAt: DateTime.now(),
    );

    // Persist to local storage
    _saveZeroOffsets();
  }

  /// Get zero offset for a device
  GaugeZeroOffset? getZeroOffset(String deviceId) {
    return _zeroOffsets[deviceId];
  }

  /// Apply zero offset to a raw reading
  double applyZeroOffset({
    required String deviceId,
    required double rawReading,
    required bool isHighSide,
  }) {
    final offset = _zeroOffsets[deviceId];
    if (offset == null) return rawReading;

    final offsetValue =
        isHighSide ? offset.highSideOffset : offset.lowSideOffset;
    return rawReading - offsetValue;
  }

  /// Notify listeners that zeroing is needed for a device
  void requestZero({
    required String deviceId,
    required String deviceName,
    required double currentHighSide,
    required double currentLowSide,
  }) {
    _zeroNeededController.add(ZeroPromptData(
      deviceId: deviceId,
      deviceName: deviceName,
      currentHighSide: currentHighSide,
      currentLowSide: currentLowSide,
    ));
  }

  /// Clear zero offset for a device
  void clearZeroOffset(String deviceId) {
    _zeroOffsets.remove(deviceId);
    _saveZeroOffsets();
  }

  /// Load zero offsets from persistent storage
  Future<void> loadZeroOffsets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('zero_offset_'));

      for (final key in keys) {
        final data = prefs.getString(key);
        if (data != null) {
          final parts = data.split('|');
          if (parts.length >= 4) {
            final deviceId = parts[0];
            _zeroOffsets[deviceId] = GaugeZeroOffset(
              deviceId: deviceId,
              highSideOffset: double.tryParse(parts[1]) ?? 0.0,
              lowSideOffset: double.tryParse(parts[2]) ?? 0.0,
              zeroedAt: DateTime.tryParse(parts[3]) ?? DateTime.now(),
            );
          }
        }
      }
    } catch (e) {
      // Silently handle load errors
    }
  }

  /// Save zero offsets to persistent storage
  Future<void> _saveZeroOffsets() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final entry in _zeroOffsets.entries) {
        final offset = entry.value;
        final data =
            '${offset.deviceId}|${offset.highSideOffset}|${offset.lowSideOffset}|${offset.zeroedAt.toIso8601String()}';
        await prefs.setString('zero_offset_${entry.key}', data);
      }
    } catch (e) {
      // Silently handle save errors
    }
  }

  void dispose() {
    _zeroNeededController.close();
  }
}

/// Data class for zero offset storage
class GaugeZeroOffset {
  final String deviceId;
  final double highSideOffset;
  final double lowSideOffset;
  final DateTime zeroedAt;

  GaugeZeroOffset({
    required this.deviceId,
    required this.highSideOffset,
    required this.lowSideOffset,
    required this.zeroedAt,
  });
}

/// Data class for zero prompt
class ZeroPromptData {
  final String deviceId;
  final String deviceName;
  final double currentHighSide;
  final double currentLowSide;

  ZeroPromptData({
    required this.deviceId,
    required this.deviceName,
    required this.currentHighSide,
    required this.currentLowSide,
  });
}
