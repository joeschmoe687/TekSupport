import '../services/refrigerant_detector.dart';

/// Pressure-Temperature chart calculator for HVAC refrigerants.
/// Used to calculate superheat and subcool from gauge readings.
class PTChart {
  static final PTChart _instance = PTChart._internal();
  factory PTChart() => _instance;
  PTChart._internal();

  /// Get saturation temperature for a given pressure and refrigerant
  /// Returns temperature in °F
  double getSaturationTemp(Refrigerant refrigerant, double pressurePsig) {
    final table = _ptTables[refrigerant];
    if (table == null) return 0.0;

    // Find the two closest pressure points and interpolate
    double? lowerPressure;
    double? upperPressure;
    double? lowerTemp;
    double? upperTemp;

    final pressures = table.keys.toList()..sort();

    for (int i = 0; i < pressures.length; i++) {
      if (pressures[i] <= pressurePsig) {
        lowerPressure = pressures[i];
        lowerTemp = table[lowerPressure];
      }
      if (pressures[i] >= pressurePsig && upperPressure == null) {
        upperPressure = pressures[i];
        upperTemp = table[upperPressure];
      }
    }

    // Exact match
    if (lowerPressure == pressurePsig) {
      return lowerTemp ?? 0.0;
    }

    // Interpolate between points
    if (lowerPressure != null &&
        upperPressure != null &&
        lowerTemp != null &&
        upperTemp != null) {
      final ratio =
          (pressurePsig - lowerPressure) / (upperPressure - lowerPressure);
      return lowerTemp + (upperTemp - lowerTemp) * ratio;
    }

    // Extrapolate if outside range
    if (lowerTemp != null) return lowerTemp;
    if (upperTemp != null) return upperTemp;
    return 0.0;
  }

  /// Get saturation pressure for a given temperature and refrigerant
  /// Returns pressure in psig
  double getSaturationPressure(Refrigerant refrigerant, double tempF) {
    final table = _ptTables[refrigerant];
    if (table == null) return 0.0;

    // Reverse lookup - find pressure for given temp
    double? lowerTemp;
    double? upperTemp;
    double? lowerPressure;
    double? upperPressure;

    for (final entry in table.entries) {
      if (entry.value <= tempF) {
        lowerTemp = entry.value;
        lowerPressure = entry.key;
      }
      if (entry.value >= tempF && upperTemp == null) {
        upperTemp = entry.value;
        upperPressure = entry.key;
      }
    }

    // Exact match
    if (lowerTemp == tempF) {
      return lowerPressure ?? 0.0;
    }

    // Interpolate
    if (lowerTemp != null &&
        upperTemp != null &&
        lowerPressure != null &&
        upperPressure != null) {
      final ratio = (tempF - lowerTemp) / (upperTemp - lowerTemp);
      return lowerPressure + (upperPressure - lowerPressure) * ratio;
    }

    if (lowerPressure != null) return lowerPressure;
    if (upperPressure != null) return upperPressure;
    return 0.0;
  }

  /// Calculate superheat
  /// Superheat = Suction Line Temp - Saturated Suction Temp
  double calculateSuperheat({
    required Refrigerant refrigerant,
    required double suctionPressure, // psig (low side)
    required double suctionLineTemp, // °F (measured at suction line)
  }) {
    final satTemp = getSaturationTemp(refrigerant, suctionPressure);
    return suctionLineTemp - satTemp;
  }

  /// Calculate subcool
  /// Subcool = Saturated Liquid Temp - Liquid Line Temp
  double calculateSubcool({
    required Refrigerant refrigerant,
    required double liquidPressure, // psig (high side)
    required double liquidLineTemp, // °F (measured at liquid line)
  }) {
    final satTemp = getSaturationTemp(refrigerant, liquidPressure);
    return satTemp - liquidLineTemp;
  }

  /// Get target superheat for fixed orifice systems
  /// Based on indoor wet bulb and outdoor dry bulb temps
  double getTargetSuperheat({
    required double outdoorDryBulb, // °F
    required double indoorWetBulb, // °F
  }) {
    // Carrier/target superheat chart approximation
    // This is a simplified version - actual charts are more detailed

    // Base superheat at 95°F OD / 67°F WB is about 10-12°F
    // Adjust for conditions

    double baseSuperheat = 10.0;

    // Adjust for outdoor temp (higher OD = lower SH)
    final odAdjust = (95 - outdoorDryBulb) * 0.15;

    // Adjust for wet bulb (higher WB = lower SH)
    final wbAdjust = (67 - indoorWetBulb) * 0.25;

    return (baseSuperheat + odAdjust + wbAdjust).clamp(5.0, 30.0);
  }

  /// Get typical subcool range for a refrigerant
  SubcoolRange getTypicalSubcool(Refrigerant refrigerant) {
    switch (refrigerant) {
      case Refrigerant.r22:
        return SubcoolRange(min: 10, max: 18, typical: 15);
      case Refrigerant.r410a:
        return SubcoolRange(min: 8, max: 14, typical: 10);
      case Refrigerant.r407c:
        return SubcoolRange(min: 10, max: 18, typical: 14);
      case Refrigerant.nu22:
        return SubcoolRange(min: 10, max: 18, typical: 15);
      case Refrigerant.r32:
        return SubcoolRange(min: 5, max: 12, typical: 8);
      case Refrigerant.r454b:
        return SubcoolRange(min: 8, max: 14, typical: 10);
      case Refrigerant.r404a:
        return SubcoolRange(min: 4, max: 10, typical: 6);
      case Refrigerant.r134a:
        return SubcoolRange(min: 5, max: 12, typical: 8);
    }
  }
}

/// Subcool range data
class SubcoolRange {
  final double min;
  final double max;
  final double typical;

  SubcoolRange({required this.min, required this.max, required this.typical});
}

// ============================================================================
// P/T Tables - Pressure (psig) to Temperature (°F)
// Common operating range values
// ============================================================================

final Map<Refrigerant, Map<double, double>> _ptTables = {
  // R-22 P/T Chart
  Refrigerant.r22: {
    0.0: -41.0,
    5.0: -28.0,
    10.0: -17.0,
    15.0: -8.0,
    20.0: 0.0,
    25.0: 7.0,
    30.0: 14.0,
    35.0: 20.0,
    40.0: 25.0,
    45.0: 30.0,
    50.0: 35.0,
    55.0: 39.0,
    60.0: 43.0,
    65.0: 47.0,
    70.0: 50.0,
    75.0: 54.0,
    80.0: 57.0,
    85.0: 60.0,
    90.0: 63.0,
    95.0: 66.0,
    100.0: 68.0,
    110.0: 74.0,
    120.0: 79.0,
    130.0: 84.0,
    140.0: 88.0,
    150.0: 92.0,
    160.0: 96.0,
    170.0: 100.0,
    180.0: 104.0,
    190.0: 107.0,
    200.0: 110.0,
    210.0: 113.0,
    220.0: 116.0,
    230.0: 119.0,
    240.0: 122.0,
    250.0: 125.0,
    260.0: 127.0,
    270.0: 130.0,
    280.0: 132.0,
    290.0: 135.0,
    300.0: 137.0,
  },

  // R-410A P/T Chart
  Refrigerant.r410a: {
    0.0: -60.0,
    20.0: -37.0,
    40.0: -20.0,
    60.0: -6.0,
    80.0: 5.0,
    100.0: 15.0,
    110.0: 19.0,
    120.0: 24.0,
    130.0: 28.0,
    140.0: 32.0,
    150.0: 35.0,
    160.0: 39.0,
    170.0: 42.0,
    180.0: 45.0,
    190.0: 48.0,
    200.0: 51.0,
    210.0: 54.0,
    220.0: 56.0,
    230.0: 59.0,
    240.0: 61.0,
    250.0: 63.0,
    260.0: 66.0,
    270.0: 68.0,
    280.0: 70.0,
    290.0: 72.0,
    300.0: 74.0,
    320.0: 78.0,
    340.0: 81.0,
    360.0: 85.0,
    380.0: 88.0,
    400.0: 91.0,
    420.0: 94.0,
    440.0: 97.0,
    460.0: 100.0,
    480.0: 103.0,
    500.0: 105.0,
    550.0: 111.0,
    600.0: 117.0,
  },

  // R-407C P/T Chart (uses bubble point for liquid, dew point for vapor)
  // This table uses bubble point (liquid side) values
  Refrigerant.r407c: {
    0.0: -43.0,
    5.0: -31.0,
    10.0: -21.0,
    15.0: -12.0,
    20.0: -4.0,
    25.0: 3.0,
    30.0: 9.0,
    35.0: 15.0,
    40.0: 20.0,
    45.0: 25.0,
    50.0: 30.0,
    55.0: 34.0,
    60.0: 38.0,
    65.0: 42.0,
    70.0: 46.0,
    75.0: 49.0,
    80.0: 52.0,
    85.0: 55.0,
    90.0: 58.0,
    95.0: 61.0,
    100.0: 64.0,
    110.0: 69.0,
    120.0: 74.0,
    130.0: 79.0,
    140.0: 83.0,
    150.0: 87.0,
    160.0: 91.0,
    170.0: 95.0,
    180.0: 99.0,
    190.0: 102.0,
    200.0: 105.0,
    220.0: 111.0,
    240.0: 117.0,
    260.0: 122.0,
    280.0: 127.0,
    300.0: 132.0,
  },

  // Nu-22 (R-422D) P/T Chart - similar to R-22
  Refrigerant.nu22: {
    0.0: -42.0,
    5.0: -29.0,
    10.0: -18.0,
    15.0: -9.0,
    20.0: -1.0,
    25.0: 6.0,
    30.0: 13.0,
    35.0: 19.0,
    40.0: 24.0,
    45.0: 29.0,
    50.0: 34.0,
    55.0: 38.0,
    60.0: 42.0,
    65.0: 46.0,
    70.0: 49.0,
    75.0: 53.0,
    80.0: 56.0,
    85.0: 59.0,
    90.0: 62.0,
    95.0: 65.0,
    100.0: 67.0,
    110.0: 73.0,
    120.0: 78.0,
    130.0: 83.0,
    140.0: 87.0,
    150.0: 91.0,
    160.0: 95.0,
    170.0: 99.0,
    180.0: 103.0,
    190.0: 106.0,
    200.0: 109.0,
    220.0: 115.0,
    240.0: 121.0,
    260.0: 126.0,
    280.0: 131.0,
    300.0: 136.0,
  },

  // R-32 P/T Chart
  Refrigerant.r32: {
    0.0: -62.0,
    20.0: -40.0,
    40.0: -24.0,
    60.0: -11.0,
    80.0: 0.0,
    100.0: 10.0,
    120.0: 18.0,
    140.0: 26.0,
    160.0: 33.0,
    180.0: 39.0,
    200.0: 45.0,
    220.0: 50.0,
    240.0: 55.0,
    260.0: 60.0,
    280.0: 64.0,
    300.0: 68.0,
    350.0: 78.0,
    400.0: 86.0,
    450.0: 94.0,
    500.0: 101.0,
    550.0: 107.0,
    600.0: 113.0,
  },

  // R-454B P/T Chart (similar to R-410A, slightly lower pressures)
  Refrigerant.r454b: {
    0.0: -58.0,
    20.0: -35.0,
    40.0: -18.0,
    60.0: -4.0,
    80.0: 7.0,
    100.0: 17.0,
    110.0: 21.0,
    120.0: 26.0,
    130.0: 30.0,
    140.0: 34.0,
    150.0: 37.0,
    160.0: 41.0,
    170.0: 44.0,
    180.0: 47.0,
    190.0: 50.0,
    200.0: 53.0,
    210.0: 56.0,
    220.0: 58.0,
    230.0: 61.0,
    240.0: 63.0,
    250.0: 65.0,
    260.0: 68.0,
    270.0: 70.0,
    280.0: 72.0,
    290.0: 74.0,
    300.0: 76.0,
    320.0: 80.0,
    340.0: 83.0,
    360.0: 87.0,
    380.0: 90.0,
    400.0: 93.0,
    420.0: 96.0,
    440.0: 99.0,
    460.0: 102.0,
    480.0: 105.0,
    500.0: 107.0,
  },

  // R-404A P/T Chart (commercial refrigeration)
  Refrigerant.r404a: {
    -5.0: -62.0,
    0.0: -59.0,
    5.0: -53.0,
    10.0: -47.0,
    15.0: -42.0,
    20.0: -37.0,
    25.0: -32.0,
    30.0: -27.0,
    35.0: -22.0,
    40.0: -17.0,
    45.0: -13.0,
    50.0: -8.0,
    60.0: 1.0,
    70.0: 9.0,
    80.0: 17.0,
    90.0: 24.0,
    100.0: 31.0,
    110.0: 38.0,
    120.0: 44.0,
    130.0: 50.0,
    140.0: 56.0,
    150.0: 61.0,
    160.0: 67.0,
    170.0: 72.0,
    180.0: 77.0,
    190.0: 82.0,
    200.0: 87.0,
    220.0: 96.0,
    240.0: 104.0,
    260.0: 112.0,
    280.0: 120.0,
    300.0: 127.0,
  },

  // R-134A P/T Chart (automotive/medium temp refrigeration)
  Refrigerant.r134a: {
    0.0: -40.0,
    5.0: -29.0,
    10.0: -20.0,
    15.0: -11.0,
    20.0: -3.0,
    25.0: 5.0,
    30.0: 12.0,
    35.0: 19.0,
    40.0: 26.0,
    45.0: 32.0,
    50.0: 38.0,
    60.0: 50.0,
    70.0: 60.0,
    80.0: 70.0,
    90.0: 79.0,
    100.0: 88.0,
    110.0: 96.0,
    120.0: 104.0,
    130.0: 111.0,
    140.0: 118.0,
    150.0: 124.0,
    160.0: 131.0,
    170.0: 137.0,
    180.0: 143.0,
    190.0: 148.0,
    200.0: 154.0,
  },
};
