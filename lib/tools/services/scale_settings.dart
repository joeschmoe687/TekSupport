import 'package:shared_preferences/shared_preferences.dart';

/// Available weight unit display formats
enum ScaleUnit {
  auto, // Auto-switch: oz for small, lb:oz for heavy (≥32oz)
  oz, // Ounces only
  lbOz, // Pounds and ounces (e.g., "3 lb 4 oz")
  kg, // Kilograms
}

/// Service for managing scale display settings
class ScaleSettings {
  static const String _unitKey = 'scaleDisplayUnit';

  // Threshold for auto-switching to lb:oz (2 lbs = 32 oz)
  static const double _autoSwitchThresholdOz = 32.0;

  static ScaleSettings? _instance;
  static ScaleSettings get instance => _instance ??= ScaleSettings._();
  ScaleSettings._();

  SharedPreferences? _prefs;
  ScaleUnit _unit = ScaleUnit.auto; // Default to auto

  ScaleUnit get unit => _unit;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final saved = _prefs?.getString(_unitKey);
    if (saved != null) {
      _unit = ScaleUnit.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => ScaleUnit.auto,
      );
    }
  }

  Future<void> setUnit(ScaleUnit unit) async {
    _unit = unit;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_unitKey, unit.name);
  }

  /// Convert ounces to the selected display unit and format the string
  String formatWeight(double ounces) {
    switch (_unit) {
      case ScaleUnit.auto:
        // Auto mode: use oz for small weights, lb:oz for heavy
        if (ounces.abs() >= _autoSwitchThresholdOz) {
          return _formatLbOz(ounces);
        }
        return '${ounces.toStringAsFixed(1)} oz';
      case ScaleUnit.oz:
        return '${ounces.toStringAsFixed(1)} oz';
      case ScaleUnit.lbOz:
        return _formatLbOz(ounces);
      case ScaleUnit.kg:
        // 1 oz = 0.0283495 kg
        final kg = ounces * 0.0283495;
        return '${kg.toStringAsFixed(3)} kg';
    }
  }

  /// Format weight as pounds and ounces
  String _formatLbOz(double ounces) {
    final totalOz = ounces.abs();
    final lbs = (totalOz / 16).floor();
    final remainingOz = totalOz % 16;
    final sign = ounces < 0 ? '-' : '';
    if (lbs == 0) {
      return '$sign${remainingOz.toStringAsFixed(1)} oz';
    }
    return '$sign$lbs lb ${remainingOz.toStringAsFixed(1)} oz';
  }

  /// Get just the numeric value in the selected unit (for display)
  double convertValue(double ounces) {
    switch (_unit) {
      case ScaleUnit.auto:
      case ScaleUnit.oz:
        return ounces;
      case ScaleUnit.lbOz:
        return ounces; // lb:oz format uses special formatting
      case ScaleUnit.kg:
        return ounces * 0.0283495;
    }
  }

  /// Get the unit suffix string
  String get unitSuffix {
    switch (_unit) {
      case ScaleUnit.auto:
        return 'auto';
      case ScaleUnit.oz:
        return 'oz';
      case ScaleUnit.lbOz:
        return 'lb:oz';
      case ScaleUnit.kg:
        return 'kg';
    }
  }

  /// Get human-readable label for a unit
  static String getUnitLabel(ScaleUnit unit) {
    switch (unit) {
      case ScaleUnit.auto:
        return 'Auto (oz → lb:oz)';
      case ScaleUnit.oz:
        return 'Ounces (oz)';
      case ScaleUnit.lbOz:
        return 'Pounds & Ounces (lb:oz)';
      case ScaleUnit.kg:
        return 'Kilograms (kg)';
    }
  }
}
