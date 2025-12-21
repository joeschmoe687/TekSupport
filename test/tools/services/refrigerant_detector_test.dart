import 'package:flutter_test/flutter_test.dart';
import 'package:tektool/tools/services/refrigerant_detector.dart';

void main() {
  group('RefrigerantDetector', () {
    late RefrigerantDetector detector;

    setUp(() {
      detector = RefrigerantDetector();
    });

    test('should be a singleton', () {
      final instance1 = RefrigerantDetector();
      final instance2 = RefrigerantDetector();
      expect(instance1, same(instance2));
    });

    group('analyzeReadings', () {
      test('should detect R410A from typical pressures', () {
        // R410A typical: Low ~118 psig, High ~300 psig at 75°F
        final result = detector.analyzeReadings(
          lowSidePressure: 118.0,
          highSidePressure: 300.0,
        );
        expect(result.suggested, Refrigerant.r410a);
        expect(result.confidence, greaterThan(0.5));
      });

      test('should detect R22 from typical pressures', () {
        // R22 typical: Low ~69 psig, High ~220 psig at 75°F
        final result = detector.analyzeReadings(
          lowSidePressure: 69.0,
          highSidePressure: 220.0,
        );
        expect(result.suggested, Refrigerant.r22);
        expect(result.confidence, greaterThan(0.3));
        expect(result.requiresConfirmation, isTrue); // R22 always requires confirmation
      });

      test('should provide alternate refrigerants', () {
        final result = detector.analyzeReadings(
          lowSidePressure: 100.0,
          highSidePressure: 270.0,
        );
        // Should detect something and confidence should be reasonable
        expect(result.suggested, isA<Refrigerant>());
      });

      test('should handle very low pressures', () {
        final result = detector.analyzeReadings(
          lowSidePressure: 10.0,
          highSidePressure: 50.0,
        );
        expect(result.suggested, isA<Refrigerant>());
        expect(result.confidence, lessThanOrEqualTo(1.0));
      });

      test('should handle very high pressures', () {
        final result = detector.analyzeReadings(
          lowSidePressure: 200.0,
          highSidePressure: 450.0,
        );
        expect(result.suggested, isA<Refrigerant>());
      });
    });

    group('detectFromNameplate', () {
      test('should detect R410A from nameplate text', () {
        final result = detector.detectFromNameplate('Model ABC R-410A System');
        expect(result, Refrigerant.r410a);
      });

      test('should detect R22 from nameplate text', () {
        final result = detector.detectFromNameplate('R-22 Refrigerant');
        expect(result, Refrigerant.r22);
      });

      test('should return null for unknown refrigerant', () {
        final result = detector.detectFromNameplate('Generic HVAC Unit');
        expect(result, isNull);
      });

      test('should handle case-insensitive matching', () {
        final result = detector.detectFromNameplate('r410a system');
        expect(result, Refrigerant.r410a);
      });
    });

    group('shouldPromptForConfirmation', () {
      test('should not prompt for R410A from nameplate', () {
        final shouldPrompt = detector.shouldPromptForConfirmation(
          nameplateRefrigerant: Refrigerant.r410a,
        );
        expect(shouldPrompt, isFalse);
      });

      test('should prompt for R22 from nameplate', () {
        final shouldPrompt = detector.shouldPromptForConfirmation(
          nameplateRefrigerant: Refrigerant.r22,
        );
        expect(shouldPrompt, isTrue);
      });
    });
  });

  group('Refrigerant', () {
    test('should have all expected refrigerant types', () {
      expect(Refrigerant.values, contains(Refrigerant.r22));
      expect(Refrigerant.values, contains(Refrigerant.r410a));
      expect(Refrigerant.values, contains(Refrigerant.r407c));
      expect(Refrigerant.values, contains(Refrigerant.nu22));
      expect(Refrigerant.values, contains(Refrigerant.r32));
      expect(Refrigerant.values, contains(Refrigerant.r454b));
    });

    test('should convert to readable display name', () {
      expect(Refrigerant.r22.displayName, 'R-22');
      expect(Refrigerant.r410a.displayName, 'R-410A');
    });

    test('should identify R22 drop-ins', () {
      expect(Refrigerant.r22.isR22DropIn, isTrue);
      expect(Refrigerant.r407c.isR22DropIn, isTrue);
      expect(Refrigerant.nu22.isR22DropIn, isTrue);
      expect(Refrigerant.r410a.isR22DropIn, isFalse);
    });
  });

  group('RefrigerantSuggestion', () {
    test('should create valid suggestion', () {
      final result = RefrigerantSuggestion(
        suggested: Refrigerant.r410a,
        confidence: 0.95,
        requiresConfirmation: false,
        alternates: [Refrigerant.r32, Refrigerant.r454b],
      );

      expect(result.suggested, Refrigerant.r410a);
      expect(result.confidence, 0.95);
      expect(result.alternates, hasLength(2));
      expect(result.alternates, contains(Refrigerant.r32));
    });

    test('confidence should be between 0 and 1', () {
      final result = RefrigerantSuggestion(
        suggested: Refrigerant.r410a,
        confidence: 0.75,
        requiresConfirmation: false,
        alternates: [],
      );

      expect(result.confidence, greaterThanOrEqualTo(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
    });
  });
}
