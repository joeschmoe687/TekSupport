import '../screens/gauge_screen.dart';
import '../services/refrigerant_detector.dart';
import 'hvac_knowledge_base.dart';

/// Real-time diagnostic engine for HVAC systems
class DiagnosticEngine {
  static final DiagnosticEngine _instance = DiagnosticEngine._internal();
  factory DiagnosticEngine() => _instance;
  DiagnosticEngine._internal();

  final HvacKnowledgeBase _knowledgeBase = HvacKnowledgeBase();

  /// Analyze current system readings and return diagnostic results
  DiagnosticResult analyze({
    required JobType systemType,
    required Refrigerant refrigerant,
    bool? isFixedOrifice,
    double? suctionPressure,
    double? dischargePressure,
    double? superheat,
    double? subcool,
    double? ambientTemp,
  }) {
    final alerts = <DiagnosticAlert>[];

    // Check suction pressure
    if (suctionPressure != null && suctionPressure > 0) {
      final expectedRange = _knowledgeBase.getExpectedPressureRange(
        systemType: systemType,
        refrigerant: refrigerant,
        isHighSide: false,
        ambientTemp: ambientTemp,
      );

      final status = _knowledgeBase.checkReading(
        actualValue: suctionPressure,
        minExpected: expectedRange.min,
        maxExpected: expectedRange.max,
      );

      if (status != ReadingStatus.normal) {
        alerts.add(DiagnosticAlert(
          type: AlertType.suctionPressure,
          status: status,
          message: _getSuctionPressureMessage(
            actual: suctionPressure,
            expected: expectedRange,
            refrigerant: refrigerant,
          ),
          possibleCauses: _getSuctionPressureCauses(
            actual: suctionPressure,
            expected: expectedRange,
            superheat: superheat,
          ),
        ));
      }
    }

    // Check discharge pressure
    if (dischargePressure != null && dischargePressure > 0) {
      final expectedRange = _knowledgeBase.getExpectedPressureRange(
        systemType: systemType,
        refrigerant: refrigerant,
        isHighSide: true,
        ambientTemp: ambientTemp,
      );

      final status = _knowledgeBase.checkReading(
        actualValue: dischargePressure,
        minExpected: expectedRange.min,
        maxExpected: expectedRange.max,
      );

      if (status != ReadingStatus.normal) {
        alerts.add(DiagnosticAlert(
          type: AlertType.dischargePressure,
          status: status,
          message: _getDischargePressureMessage(
            actual: dischargePressure,
            expected: expectedRange,
            refrigerant: refrigerant,
          ),
          possibleCauses: _getDischargePressureCauses(
            actual: dischargePressure,
            expected: expectedRange,
            subcool: subcool,
          ),
        ));
      }
    }

    // Check superheat
    if (superheat != null && superheat > 0) {
      final expectedRange = _knowledgeBase.getExpectedSuperheat(
        systemType: systemType,
        isFixedOrifice: isFixedOrifice,
      );

      final status = _knowledgeBase.checkReading(
        actualValue: superheat,
        minExpected: expectedRange.min,
        maxExpected: expectedRange.max,
      );

      if (status != ReadingStatus.normal) {
        alerts.add(DiagnosticAlert(
          type: AlertType.superheat,
          status: status,
          message: _getSuperheatMessage(
            actual: superheat,
            expected: expectedRange,
          ),
          possibleCauses: _getSuperheatCauses(
            actual: superheat,
            expected: expectedRange,
            isFixedOrifice: isFixedOrifice,
          ),
        ));
      }
    }

    // Check subcool
    if (subcool != null && subcool > 0) {
      final expectedRange = _knowledgeBase.getExpectedSubcool(
        systemType: systemType,
        refrigerant: refrigerant,
      );

      final status = _knowledgeBase.checkReading(
        actualValue: subcool,
        minExpected: expectedRange.min,
        maxExpected: expectedRange.max,
      );

      if (status != ReadingStatus.normal) {
        alerts.add(DiagnosticAlert(
          type: AlertType.subcool,
          status: status,
          message: _getSubcoolMessage(
            actual: subcool,
            expected: expectedRange,
          ),
          possibleCauses: _getSubcoolCauses(
            actual: subcool,
            expected: expectedRange,
          ),
        ));
      }
    }

    // Analyze symptom combinations for advanced diagnostics
    final combinedDiagnostic = _analyzeCombinedSymptoms(
      suctionPressure: suctionPressure,
      dischargePressure: dischargePressure,
      superheat: superheat,
      subcool: subcool,
      systemType: systemType,
      refrigerant: refrigerant,
    );

    return DiagnosticResult(
      alerts: alerts,
      overallStatus: _getOverallStatus(alerts),
      combinedDiagnostic: combinedDiagnostic,
    );
  }

  // Message generators
  String _getSuctionPressureMessage({
    required double actual,
    required PressureRange expected,
    required Refrigerant refrigerant,
  }) {
    if (actual < expected.min) {
      return 'Suction pressure ${actual.toStringAsFixed(1)} PSI is LOW for ${refrigerant.displayName}. Expected: ${expected.min.toStringAsFixed(0)}-${expected.max.toStringAsFixed(0)} PSI';
    }
    return 'Suction pressure ${actual.toStringAsFixed(1)} PSI is HIGH for ${refrigerant.displayName}. Expected: ${expected.min.toStringAsFixed(0)}-${expected.max.toStringAsFixed(0)} PSI';
  }

  String _getDischargePressureMessage({
    required double actual,
    required PressureRange expected,
    required Refrigerant refrigerant,
  }) {
    if (actual < expected.min) {
      return 'Discharge pressure ${actual.toStringAsFixed(1)} PSI is LOW for ${refrigerant.displayName}. Expected: ${expected.min.toStringAsFixed(0)}-${expected.max.toStringAsFixed(0)} PSI';
    }
    return 'Discharge pressure ${actual.toStringAsFixed(1)} PSI is HIGH for ${refrigerant.displayName}. Expected: ${expected.min.toStringAsFixed(0)}-${expected.max.toStringAsFixed(0)} PSI';
  }

  String _getSuperheatMessage({
    required double actual,
    required SuperheatRange expected,
  }) {
    if (actual < expected.min) {
      return 'Superheat ${actual.toStringAsFixed(1)}°F is LOW. Expected: ${expected.min.toStringAsFixed(0)}-${expected.max.toStringAsFixed(0)}°F';
    }
    return 'Superheat ${actual.toStringAsFixed(1)}°F is HIGH. Expected: ${expected.min.toStringAsFixed(0)}-${expected.max.toStringAsFixed(0)}°F';
  }

  String _getSubcoolMessage({
    required double actual,
    required SubcoolRange expected,
  }) {
    if (actual < expected.min) {
      return 'Subcool ${actual.toStringAsFixed(1)}°F is LOW. Expected: ${expected.min.toStringAsFixed(0)}-${expected.max.toStringAsFixed(0)}°F';
    }
    return 'Subcool ${actual.toStringAsFixed(1)}°F is HIGH. Expected: ${expected.min.toStringAsFixed(0)}-${expected.max.toStringAsFixed(0)}°F';
  }

  // Cause generators
  List<String> _getSuctionPressureCauses(
      {required double actual,
      required PressureRange expected,
      double? superheat}) {
    if (actual < expected.min) {
      // Low suction
      final causes = [
        'Low refrigerant charge',
        'Restricted metering device (TXV or orifice)',
        'Restricted liquid line filter/drier',
        'Evaporator airflow restriction',
      ];
      if (superheat != null && superheat > 15) {
        causes.insert(0, 'Low charge (confirmed by high superheat)');
      }
      return causes;
    } else {
      // High suction
      return [
        'Overcharged system',
        'TXV stuck open or failing',
        'Excessive evaporator load',
        'Compressor inefficiency',
      ];
    }
  }

  List<String> _getDischargePressureCauses(
      {required double actual,
      required PressureRange expected,
      double? subcool}) {
    if (actual < expected.min) {
      // Low discharge
      return [
        'Low refrigerant charge',
        'Compressor efficiency loss',
        'Discharge valve failure',
      ];
    } else {
      // High discharge
      final causes = [
        'Condenser airflow restriction (dirty coil)',
        'Condenser fan motor failure',
        'Ambient temperature very high',
        'Overcharge',
        'Non-condensables in system',
      ];
      if (subcool != null && subcool > 15) {
        causes.insert(0, 'Overcharge (confirmed by high subcool)');
      }
      return causes;
    }
  }

  List<String> _getSuperheatCauses({
    required double actual,
    required SuperheatRange expected,
    bool? isFixedOrifice,
  }) {
    if (actual < expected.min) {
      // Low superheat (flooding)
      return [
        'Overcharge',
        'TXV stuck open or oversized',
        'Sensing bulb loose or improperly located',
        'Evaporator airflow too high',
      ];
    } else {
      // High superheat (starving)
      final causes = [
        'Low refrigerant charge',
        'Restricted liquid line',
        'TXV sensing bulb loose',
        'Evaporator airflow restriction',
      ];
      if (isFixedOrifice == true) {
        causes.add('Fixed orifice undersized for conditions');
      } else {
        causes.add('TXV failing or restricted');
      }
      return causes;
    }
  }

  List<String> _getSubcoolCauses(
      {required double actual, required SubcoolRange expected}) {
    if (actual < expected.min) {
      // Low subcool
      return [
        'Low refrigerant charge',
        'Restriction before condenser',
        'Condenser undersized or fouled',
      ];
    } else {
      // High subcool
      return [
        'Overcharge',
        'Condenser oversized for load',
        'Low ambient temperature',
        'Liquid line restriction',
      ];
    }
  }

  // Combined symptom analysis
  String? _analyzeCombinedSymptoms({
    double? suctionPressure,
    double? dischargePressure,
    double? superheat,
    double? subcool,
    required JobType systemType,
    required Refrigerant refrigerant,
  }) {
    // Get expected ranges
    final lowExpected = _knowledgeBase.getExpectedPressureRange(
      systemType: systemType,
      refrigerant: refrigerant,
      isHighSide: false,
    );
    final highExpected = _knowledgeBase.getExpectedPressureRange(
      systemType: systemType,
      refrigerant: refrigerant,
      isHighSide: true,
    );

    // Classic low charge pattern
    if (suctionPressure != null &&
        dischargePressure != null &&
        superheat != null &&
        subcool != null) {
      if (suctionPressure < lowExpected.min &&
          dischargePressure < highExpected.min &&
          superheat > 15 &&
          subcool < 5) {
        return '⚠️ Classic LOW CHARGE pattern detected:\n'
            '• Low suction & discharge pressures\n'
            '• High superheat (${superheat.toStringAsFixed(1)}°F)\n'
            '• Low subcool (${subcool.toStringAsFixed(1)}°F)\n'
            '→ Add refrigerant and recheck';
      }

      // Classic overcharge pattern
      if (suctionPressure > lowExpected.max &&
          dischargePressure > highExpected.max &&
          superheat < 8 &&
          subcool > 15) {
        return '⚠️ Classic OVERCHARGE pattern detected:\n'
            '• High suction & discharge pressures\n'
            '• Low superheat (${superheat.toStringAsFixed(1)}°F)\n'
            '• High subcool (${subcool.toStringAsFixed(1)}°F)\n'
            '→ Recover refrigerant and recheck';
      }

      // TXV flooding
      if (suctionPressure > lowExpected.max && superheat < 5) {
        return '⚠️ TXV FLOODING pattern detected:\n'
            '• High suction pressure\n'
            '• Very low superheat (${superheat.toStringAsFixed(1)}°F)\n'
            '→ Check TXV sensing bulb and adjustment';
      }

      // Restricted metering device
      if (suctionPressure < lowExpected.min && superheat > 20) {
        return '⚠️ RESTRICTED METERING DEVICE pattern:\n'
            '• Low suction pressure\n'
            '• Very high superheat (${superheat.toStringAsFixed(1)}°F)\n'
            '→ Check TXV, filter drier, or liquid line';
      }
    }

    return null; // No combined pattern detected
  }

  ReadingStatus _getOverallStatus(List<DiagnosticAlert> alerts) {
    if (alerts.any((a) => a.status == ReadingStatus.critical)) {
      return ReadingStatus.critical;
    }
    if (alerts.any((a) => a.status == ReadingStatus.warning)) {
      return ReadingStatus.warning;
    }
    return ReadingStatus.normal;
  }
}

/// Result of diagnostic analysis
class DiagnosticResult {
  final List<DiagnosticAlert> alerts;
  final ReadingStatus overallStatus;
  final String? combinedDiagnostic; // Advanced pattern recognition

  DiagnosticResult({
    required this.alerts,
    required this.overallStatus,
    this.combinedDiagnostic,
  });

  bool get hasIssues => alerts.isNotEmpty;
}

/// Individual diagnostic alert
class DiagnosticAlert {
  final AlertType type;
  final ReadingStatus status;
  final String message;
  final List<String> possibleCauses;

  DiagnosticAlert({
    required this.type,
    required this.status,
    required this.message,
    required this.possibleCauses,
  });
}

/// Type of diagnostic alert
enum AlertType {
  suctionPressure,
  dischargePressure,
  superheat,
  subcool,
}
