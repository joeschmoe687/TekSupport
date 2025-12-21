import 'package:flutter_test/flutter_test.dart';
import 'package:tektool/tools/utils/pt_chart.dart';
import 'package:tektool/tools/services/refrigerant_detector.dart';

void main() {
  group('PTChart', () {
    late PTChart ptChart;

    setUp(() {
      ptChart = PTChart();
    });

    test('should be a singleton', () {
      final instance1 = PTChart();
      final instance2 = PTChart();
      expect(instance1, same(instance2));
    });

    group('getSaturationTemp', () {
      test('should return correct saturation temp for R410A at 118 psig', () {
        // R410A at 118 psig should be around 40°F (low side)
        final temp = ptChart.getSaturationTemp(Refrigerant.r410a, 118.0);
        expect(temp, greaterThan(35.0));
        expect(temp, lessThan(45.0));
      });

      test('should return correct saturation temp for R22 at 69 psig', () {
        // R22 at 69 psig should be around 40°F (low side)
        final temp = ptChart.getSaturationTemp(Refrigerant.r22, 69.0);
        expect(temp, greaterThan(35.0));
        expect(temp, lessThan(45.0));
      });

      test('should handle zero pressure', () {
        final temp = ptChart.getSaturationTemp(Refrigerant.r410a, 0.0);
        expect(temp, isA<double>());
        expect(temp, isNonNegative);
      });

      test('should handle very high pressure', () {
        final temp = ptChart.getSaturationTemp(Refrigerant.r410a, 500.0);
        expect(temp, isA<double>());
        expect(temp, greaterThan(0.0));
      });
    });

    group('getSaturationPressure', () {
      test('should return correct saturation pressure for R410A at 40°F', () {
        // R410A at 40°F should be around 118 psig (low side)
        final pressure = ptChart.getSaturationPressure(Refrigerant.r410a, 40.0);
        expect(pressure, greaterThan(100.0));
        expect(pressure, lessThan(135.0));
      });

      test('should return correct saturation pressure for R22 at 40°F', () {
        // R22 at 40°F should be around 69 psig (low side)
        final pressure = ptChart.getSaturationPressure(Refrigerant.r22, 40.0);
        expect(pressure, greaterThan(60.0));
        expect(pressure, lessThan(80.0));
      });

      test('should handle zero temperature', () {
        final pressure = ptChart.getSaturationPressure(Refrigerant.r410a, 0.0);
        expect(pressure, isA<double>());
        expect(pressure, isNonNegative);
      });
    });

    group('calculateSuperheat', () {
      test('should calculate superheat correctly', () {
        // If suction line temp is 50°F and low side pressure gives 40°F sat temp
        // Superheat = 50 - 40 = 10°F
        final superheat = ptChart.calculateSuperheat(
          refrigerant: Refrigerant.r410a,
          suctionLineTemp: 50.0,
          suctionPressure: 118.0,
        );
        expect(superheat, greaterThan(0.0));
        expect(superheat, lessThan(20.0));
      });

      test('should handle zero superheat', () {
        // When line temp equals saturation temp
        final superheat = ptChart.calculateSuperheat(
          refrigerant: Refrigerant.r410a,
          suctionLineTemp: 40.0,
          suctionPressure: 118.0,
        );
        expect(superheat, lessThanOrEqualTo(5.0));
        expect(superheat, greaterThanOrEqualTo(-5.0));
      });
    });

    group('calculateSubcool', () {
      test('should calculate subcool correctly', () {
        // If liquid line temp is 100°F and high side pressure gives 110°F sat temp
        // Subcool = 110 - 100 = 10°F
        final subcool = ptChart.calculateSubcool(
          refrigerant: Refrigerant.r410a,
          liquidLineTemp: 100.0,
          liquidPressure: 300.0,
        );
        expect(subcool, greaterThan(0.0));
        expect(subcool, lessThan(30.0));
      });

      test('should handle zero subcool', () {
        final subcool = ptChart.calculateSubcool(
          refrigerant: Refrigerant.r410a,
          liquidLineTemp: 110.0,
          liquidPressure: 300.0,
        );
        expect(subcool, isA<double>());
      });
    });

    group('getTargetSuperheat', () {
      test('should return target superheat for fixed orifice', () {
        final target = ptChart.getTargetSuperheat(
          outdoorDryBulb: 75.0,
          indoorWetBulb: 63.0,
        );
        expect(target, greaterThan(0.0));
        expect(target, lessThan(30.0));
      });

      test('should handle extreme temperatures', () {
        final target = ptChart.getTargetSuperheat(
          outdoorDryBulb: 115.0,
          indoorWetBulb: 80.0,
        );
        expect(target, greaterThan(0.0));
      });
    });
  });
}
