import '../screens/gauge_screen.dart';
import '../services/refrigerant_detector.dart';

/// HVAC industry standard expected ranges for different system types
class HvacKnowledgeBase {
  static final HvacKnowledgeBase _instance = HvacKnowledgeBase._internal();
  factory HvacKnowledgeBase() => _instance;
  HvacKnowledgeBase._internal();

  /// Get expected pressure range for a system
  PressureRange getExpectedPressureRange({
    required JobType systemType,
    required Refrigerant refrigerant,
    required bool isHighSide,
    double? ambientTemp, // Optional ambient temp for compensation
  }) {
    final baseRange = _getBasePressureRange(
      systemType: systemType,
      refrigerant: refrigerant,
      isHighSide: isHighSide,
    );

    // Apply ambient temperature compensation if provided
    if (ambientTemp != null && isHighSide) {
      return _compensateForAmbient(baseRange, ambientTemp);
    }

    return baseRange;
  }

  /// Get expected superheat range
  SuperheatRange getExpectedSuperheat({
    required JobType systemType,
    bool? isFixedOrifice,
  }) {
    // TXV systems: tighter control
    if (isFixedOrifice == false) {
      return SuperheatRange(min: 10, max: 15, target: 12);
    }

    // Fixed orifice: wider range, depends on conditions
    if (isFixedOrifice == true) {
      return SuperheatRange(min: 8, max: 20, target: 12);
    }

    // Refrigeration systems typically run lower superheat
    if (systemType == JobType.refrigerationCooler ||
        systemType == JobType.refrigerationFreezer ||
        systemType == JobType.refrigerationIceMachine) {
      return SuperheatRange(min: 6, max: 12, target: 8);
    }

    // Default for unknown metering device
    return SuperheatRange(min: 8, max: 18, target: 12);
  }

  /// Get expected subcool range
  SubcoolRange getExpectedSubcool({
    required JobType systemType,
    required Refrigerant refrigerant,
  }) {
    // Most systems target 8-15°F subcool
    if (systemType == JobType.refrigerationCooler ||
        systemType == JobType.refrigerationFreezer ||
        systemType == JobType.refrigerationIceMachine) {
      return SubcoolRange(min: 4, max: 10, target: 6);
    }

    // AC and heat pump
    return SubcoolRange(min: 8, max: 15, target: 10);
  }

  /// Base pressure ranges without ambient compensation
  PressureRange _getBasePressureRange({
    required JobType systemType,
    required Refrigerant refrigerant,
    required bool isHighSide,
  }) {
    // Define ranges for different system types and refrigerants
    final key = _RangeKey(systemType, refrigerant, isHighSide);

    // Residential AC ranges
    if (systemType == JobType.airConditioning) {
      if (refrigerant == Refrigerant.r410a) {
        return isHighSide
            ? PressureRange(min: 350, max: 425, target: 385)
            : PressureRange(min: 118, max: 145, target: 130);
      } else if (refrigerant == Refrigerant.r22) {
        return isHighSide
            ? PressureRange(min: 225, max: 275, target: 250)
            : PressureRange(min: 65, max: 80, target: 72);
      } else if (refrigerant == Refrigerant.r407c ||
          refrigerant == Refrigerant.nu22) {
        return isHighSide
            ? PressureRange(min: 220, max: 270, target: 245)
            : PressureRange(min: 64, max: 78, target: 70);
      }
    }

    // Heat pump cooling mode (same as AC)
    if (systemType == JobType.heatPump) {
      if (refrigerant == Refrigerant.r410a) {
        return isHighSide
            ? PressureRange(min: 350, max: 425, target: 385)
            : PressureRange(min: 118, max: 145, target: 130);
      } else if (refrigerant == Refrigerant.r22) {
        return isHighSide
            ? PressureRange(min: 225, max: 275, target: 250)
            : PressureRange(min: 65, max: 80, target: 72);
      }
    }

    // Walk-in cooler
    if (systemType == JobType.refrigerationCooler) {
      if (refrigerant == Refrigerant.r404a) {
        return isHighSide
            ? PressureRange(min: 180, max: 225, target: 200)
            : PressureRange(min: 20, max: 35, target: 28);
      } else if (refrigerant == Refrigerant.r134a) {
        return isHighSide
            ? PressureRange(min: 120, max: 160, target: 140)
            : PressureRange(min: 15, max: 30, target: 22);
      }
    }

    // Walk-in freezer
    if (systemType == JobType.refrigerationFreezer) {
      if (refrigerant == Refrigerant.r404a) {
        return isHighSide
            ? PressureRange(min: 180, max: 225, target: 200)
            : PressureRange(min: 5, max: 15, target: 10);
      }
    }

    // Ice machine
    if (systemType == JobType.refrigerationIceMachine) {
      if (refrigerant == Refrigerant.r404a) {
        return isHighSide
            ? PressureRange(min: 150, max: 200, target: 175)
            : PressureRange(min: 15, max: 30, target: 22);
      }
    }

    // Default fallback
    return isHighSide
        ? PressureRange(min: 200, max: 400, target: 300)
        : PressureRange(min: 50, max: 150, target: 100);
  }

  /// Compensate high-side pressure range for ambient temperature
  PressureRange _compensateForAmbient(
      PressureRange baseRange, double ambientTemp) {
    // Rule of thumb: high-side pressure changes ~5-10 PSI per 5°F ambient change
    // Base ranges assume 95°F outdoor temp
    const baseAmbient = 95.0;
    final tempDelta = ambientTemp - baseAmbient;
    final pressureAdjustment = tempDelta * 2.0; // ~10 PSI per 5°F

    return PressureRange(
      min: baseRange.min + pressureAdjustment,
      max: baseRange.max + pressureAdjustment,
      target: baseRange.target + pressureAdjustment,
    );
  }

  /// Check if reading is within acceptable range
  ReadingStatus checkReading({
    required double actualValue,
    required double minExpected,
    required double maxExpected,
  }) {
    final range = maxExpected - minExpected;
    final midpoint = (maxExpected + minExpected) / 2;

    // Check if critically out of range (>20% deviation)
    if (actualValue < minExpected - range * 0.2 ||
        actualValue > maxExpected + range * 0.2) {
      return ReadingStatus.critical;
    }

    // Check if in warning range (10-20% deviation)
    if (actualValue < minExpected - range * 0.1 ||
        actualValue > maxExpected + range * 0.1) {
      return ReadingStatus.warning;
    }

    // Within acceptable range
    return ReadingStatus.normal;
  }
}

/// Pressure range (PSI)
class PressureRange {
  final double min;
  final double max;
  final double target;

  PressureRange({
    required this.min,
    required this.max,
    required this.target,
  });
}

/// Superheat range (°F)
class SuperheatRange {
  final double min;
  final double max;
  final double target;

  SuperheatRange({
    required this.min,
    required this.max,
    required this.target,
  });
}

/// Subcool range (°F)
class SubcoolRange {
  final double min;
  final double max;
  final double target;

  SubcoolRange({
    required this.min,
    required this.max,
    required this.target,
  });
}

/// Status of a reading compared to expected range
enum ReadingStatus {
  normal, // Within expected range (green)
  warning, // 10-20% out of range (yellow)
  critical, // >20% out of range (red)
}

/// Key for range lookup
class _RangeKey {
  final JobType systemType;
  final Refrigerant refrigerant;
  final bool isHighSide;

  _RangeKey(this.systemType, this.refrigerant, this.isHighSide);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RangeKey &&
          systemType == other.systemType &&
          refrigerant == other.refrigerant &&
          isHighSide == other.isHighSide;

  @override
  int get hashCode =>
      systemType.hashCode ^ refrigerant.hashCode ^ isHighSide.hashCode;
}
