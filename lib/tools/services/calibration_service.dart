import 'package:shared_preferences/shared_preferences.dart';

/// Calibration service for sensor offset adjustments
/// Stores offsets per device/sensor type, persists to SharedPreferences
class CalibrationService {
  static final CalibrationService _instance = CalibrationService._internal();
  factory CalibrationService() => _instance;
  CalibrationService._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // Calibration offset keys
  static const String _keyPrefix = 'calibration_';

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Get calibration offset for a sensor
  /// [sensorKey] format: "deviceType_sensorName" (e.g., "abm200_temperature")
  double getOffset(String sensorKey) {
    if (_prefs == null) return 0.0;
    return _prefs!.getDouble('$_keyPrefix$sensorKey') ?? 0.0;
  }

  /// Set calibration offset for a sensor
  Future<void> setOffset(String sensorKey, double offset) async {
    if (_prefs == null) await init();
    await _prefs!.setDouble('$_keyPrefix$sensorKey', offset);
  }

  /// Clear calibration offset for a sensor
  Future<void> clearOffset(String sensorKey) async {
    if (_prefs == null) await init();
    await _prefs!.remove('$_keyPrefix$sensorKey');
  }

  /// Get all calibration offsets (for debugging)
  Map<String, double> getAllOffsets() {
    if (_prefs == null) return {};
    final keys = _prefs!.getKeys().where((k) => k.startsWith(_keyPrefix));
    return {
      for (final key in keys)
        key.replaceFirst(_keyPrefix, ''): _prefs!.getDouble(key) ?? 0.0
    };
  }

  /// Clear all calibration offsets
  Future<void> clearAllOffsets() async {
    if (_prefs == null) await init();
    final keys =
        _prefs!.getKeys().where((k) => k.startsWith(_keyPrefix)).toList();
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }
}

/// Calibration offset keys for ABM-200 airflow meter
/// Note: Pressure is barometric and doesn't need calibration
/// Note: Scales and pressure gauges have hardware zero - no calibration needed
class Abm200CalibrationKeys {
  static const String velocity = 'abm200_velocity';
  static const String temperature = 'abm200_temperature';
  static const String humidity = 'abm200_humidity';
}
