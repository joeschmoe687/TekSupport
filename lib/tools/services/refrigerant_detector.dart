/// Service to auto-detect refrigerant type from pressure readings
/// and prompt user for confirmation, especially for R22 systems.
class RefrigerantDetector {
  static final RefrigerantDetector _instance = RefrigerantDetector._internal();
  factory RefrigerantDetector() => _instance;
  RefrigerantDetector._internal();

  /// Analyze pressure readings and outdoor temp to suggest refrigerant type.
  /// Returns a refrigerant suggestion with confidence level.
  RefrigerantSuggestion analyzeReadings({
    required double highSidePressure, // psig
    required double lowSidePressure, // psig
    double? outdoorTemp, // °F (optional, improves accuracy)
  }) {
    // Use default outdoor temp if not provided
    final ambient = outdoorTemp ?? 95.0;

    // Calculate expected saturation pressures for each refrigerant at this temp
    final r22Expected = _getExpectedPressures(Refrigerant.r22, ambient);
    final r410aExpected = _getExpectedPressures(Refrigerant.r410a, ambient);
    final r407cExpected = _getExpectedPressures(Refrigerant.r407c, ambient);

    // Compare actual readings to expected ranges
    final r22Score = _calculateMatchScore(
      highSidePressure,
      lowSidePressure,
      r22Expected.highSide,
      r22Expected.lowSide,
    );
    final r410aScore = _calculateMatchScore(
      highSidePressure,
      lowSidePressure,
      r410aExpected.highSide,
      r410aExpected.lowSide,
    );
    final r407cScore = _calculateMatchScore(
      highSidePressure,
      lowSidePressure,
      r407cExpected.highSide,
      r407cExpected.lowSide,
    );

    // Determine best match
    if (r410aScore > r22Score && r410aScore > r407cScore) {
      return RefrigerantSuggestion(
        suggested: Refrigerant.r410a,
        confidence: r410aScore,
        requiresConfirmation: false, // R410A is clear, no drop-in confusion
        alternates: [],
      );
    }

    // R22 and R407C have similar pressures - always confirm for R22 range
    if (r22Score >= r407cScore) {
      return RefrigerantSuggestion(
        suggested: Refrigerant.r22,
        confidence: r22Score,
        requiresConfirmation: true, // Always confirm R22 - could be drop-in
        alternates: [Refrigerant.r407c, Refrigerant.nu22],
      );
    }

    return RefrigerantSuggestion(
      suggested: Refrigerant.r407c,
      confidence: r407cScore,
      requiresConfirmation: true, // R407C range overlaps R22
      alternates: [Refrigerant.r22, Refrigerant.nu22],
    );
  }

  /// Check if a refrigerant was detected from OCR nameplate scan
  /// Returns the refrigerant if detected, null otherwise
  Refrigerant? detectFromNameplate(String? nameplateText) {
    if (nameplateText == null || nameplateText.isEmpty) return null;

    final text = nameplateText.toUpperCase();

    // Check for specific refrigerant mentions
    if (text.contains('R-410A') ||
        text.contains('R410A') ||
        text.contains('410A')) {
      return Refrigerant.r410a;
    }
    if (text.contains('R-32') || text.contains('R32')) {
      return Refrigerant.r32;
    }
    if (text.contains('R-454B') || text.contains('R454B')) {
      return Refrigerant.r454b;
    }
    if (text.contains('R-407C') ||
        text.contains('R407C') ||
        text.contains('407C')) {
      return Refrigerant.r407c;
    }
    if (text.contains('NU-22') || text.contains('NU22')) {
      return Refrigerant.nu22;
    }
    // R22 detection - but still requires confirmation due to potential drop-in
    if (text.contains('R-22') ||
        text.contains('R22') ||
        text.contains('HCFC-22')) {
      return Refrigerant.r22; // Will still prompt for drop-in confirmation
    }

    return null;
  }

  /// Determine if we should prompt for refrigerant confirmation
  bool shouldPromptForConfirmation({
    Refrigerant? nameplateRefrigerant,
    RefrigerantSuggestion? pressureSuggestion,
  }) {
    // If nameplate shows R410A, R32, R454B - no confirmation needed
    if (nameplateRefrigerant != null) {
      switch (nameplateRefrigerant) {
        case Refrigerant.r410a:
        case Refrigerant.r32:
        case Refrigerant.r454b:
          return false;
        case Refrigerant.r22:
        case Refrigerant.r407c:
        case Refrigerant.nu22:
          // R22 family always needs confirmation - could be swapped
          return true;
        default:
          return true;
      }
    }

    // No nameplate data - use pressure suggestion
    if (pressureSuggestion != null) {
      return pressureSuggestion.requiresConfirmation;
    }

    // No data at all - need confirmation
    return true;
  }

  /// Get expected high/low side pressures for a refrigerant at given ambient temp
  _ExpectedPressures _getExpectedPressures(
      Refrigerant refrigerant, double ambientTemp) {
    // Rough estimates for typical A/C operation
    // High side: condensing temp ~20-30°F above ambient
    // Low side: evaporating temp ~35-45°F

    final condensingTemp = ambientTemp + 25;
    final evaporatingTemp = 40.0;

    final highSide = _getSaturationPressure(refrigerant, condensingTemp);
    final lowSide = _getSaturationPressure(refrigerant, evaporatingTemp);

    return _ExpectedPressures(highSide: highSide, lowSide: lowSide);
  }

  /// Get saturation pressure for a refrigerant at a given temperature
  /// Uses simplified lookup - see pt_chart.dart for full tables
  double _getSaturationPressure(Refrigerant refrigerant, double tempF) {
    switch (refrigerant) {
      case Refrigerant.r22:
        // Simplified R22 P/T approximation
        return 0.0458 * tempF * tempF + 0.7143 * tempF - 9.5;
      case Refrigerant.r410a:
        // Simplified R410A P/T approximation (runs ~1.6x higher than R22)
        return 0.0733 * tempF * tempF + 1.143 * tempF - 15.2;
      case Refrigerant.r407c:
        // R407C is similar to R22, slightly higher
        return 0.0475 * tempF * tempF + 0.75 * tempF - 10.0;
      case Refrigerant.nu22:
        // Nu-22 (R422D) is similar to R22
        return 0.046 * tempF * tempF + 0.72 * tempF - 9.8;
      case Refrigerant.r32:
        // R32 runs higher than R410A
        return 0.08 * tempF * tempF + 1.2 * tempF - 16.0;
      case Refrigerant.r454b:
        // R454B similar to R410A
        return 0.072 * tempF * tempF + 1.1 * tempF - 14.5;
      case Refrigerant.r404a:
        // R404A - commercial refrigeration, similar to R410A
        return 0.07 * tempF * tempF + 1.0 * tempF - 13.0;
      case Refrigerant.r134a:
        // R134A - automotive/light commercial, lower pressure
        return 0.035 * tempF * tempF + 0.55 * tempF - 7.0;
    }
  }

  /// Calculate how well actual readings match expected readings
  double _calculateMatchScore(
    double actualHigh,
    double actualLow,
    double expectedHigh,
    double expectedLow,
  ) {
    // Calculate percentage difference
    final highDiff = (actualHigh - expectedHigh).abs() / expectedHigh;
    final lowDiff = (actualLow - expectedLow).abs() / expectedLow;

    // Convert to 0-1 score (1 = perfect match)
    final highScore = (1 - highDiff).clamp(0.0, 1.0);
    final lowScore = (1 - lowDiff).clamp(0.0, 1.0);

    return (highScore + lowScore) / 2;
  }
}

/// Supported refrigerants
enum Refrigerant {
  r22,
  r410a,
  r407c,
  nu22, // R422D
  r32,
  r454b,
  r404a, // Commercial refrigeration
  r134a, // Automotive/refrigeration
}

extension RefrigerantExtension on Refrigerant {
  String get displayName {
    switch (this) {
      case Refrigerant.r22:
        return 'R-22';
      case Refrigerant.r410a:
        return 'R-410A';
      case Refrigerant.r407c:
        return 'R-407C';
      case Refrigerant.nu22:
        return 'Nu-22';
      case Refrigerant.r32:
        return 'R-32';
      case Refrigerant.r454b:
        return 'R-454B';
      case Refrigerant.r404a:
        return 'R-404A';
      case Refrigerant.r134a:
        return 'R-134A';
    }
  }

  bool get isR22DropIn {
    switch (this) {
      case Refrigerant.r22:
      case Refrigerant.r407c:
      case Refrigerant.nu22:
        return true;
      default:
        return false;
    }
  }
}

/// Suggestion result from pressure analysis
class RefrigerantSuggestion {
  final Refrigerant suggested;
  final double confidence; // 0-1
  final bool requiresConfirmation;
  final List<Refrigerant> alternates;

  RefrigerantSuggestion({
    required this.suggested,
    required this.confidence,
    required this.requiresConfirmation,
    required this.alternates,
  });
}

class _ExpectedPressures {
  final double highSide;
  final double lowSide;

  _ExpectedPressures({required this.highSide, required this.lowSide});
}
