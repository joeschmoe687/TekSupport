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

    group('detectFromPressures', () {
      test('should detect R410A from typical pressures', () {
        // R410A typical: Low ~118 psig, High ~300 psig at 75°F
        final result = detector.detectFromPressures(
          lowSidePsig: 118.0,
          highSidePsig: 300.0,
        );
        expect(result.primary, Refrigerant.r410a);
        expect(result.confidence, greaterThan(0.5));
      });

      test('should detect R22 from typical pressures', () {
        // R22 typical: Low ~69 psig, High ~220 psig at 75°F
        final result = detector.detectFromPressures(
          lowSidePsig: 69.0,
          highSidePsig: 220.0,
        );
        expect(result.primary, Refrigerant.r22);
        expect(result.confidence, greaterThan(0.5));
      });

      test('should provide alternate refrigerants', () {
        final result = detector.detectFromPressures(
          lowSidePsig: 100.0,
          highSidePsig: 270.0,
        );
        expect(result.alternates, isNotEmpty);
      });

      test('should handle very low pressures', () {
        final result = detector.detectFromPressures(
          lowSidePsig: 10.0,
          highSidePsig: 50.0,
        );
        expect(result.primary, isA<Refrigerant>());
        expect(result.confidence, lessThanOrEqualTo(1.0));
      });

      test('should handle very high pressures', () {
        final result = detector.detectFromPressures(
          lowSidePsig: 200.0,
          highSidePsig: 450.0,
        );
        expect(result.primary, isA<Refrigerant>());
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

    test('should convert to readable name', () {
      expect(Refrigerant.r22.toString(), contains('r22'));
      expect(Refrigerant.r410a.toString(), contains('r410a'));
    });
  });

  group('RefrigerantDetectionResult', () {
    test('should create valid result', () {
      final result = RefrigerantDetectionResult(
        primary: Refrigerant.r410a,
        confidence: 0.95,
        alternates: [Refrigerant.r32, Refrigerant.r454b],
      );

      expect(result.primary, Refrigerant.r410a);
      expect(result.confidence, 0.95);
      expect(result.alternates, hasLength(2));
      expect(result.alternates, contains(Refrigerant.r32));
    });

    test('confidence should be between 0 and 1', () {
      final result = RefrigerantDetectionResult(
        primary: Refrigerant.r410a,
        confidence: 0.75,
        alternates: [],
      );

      expect(result.confidence, greaterThanOrEqualTo(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
    });
  });
}
