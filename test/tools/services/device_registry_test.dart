import 'package:flutter_test/flutter_test.dart';
import 'package:tektool/tools/services/device_registry.dart';

void main() {
  group('DeviceRegistry', () {
    late DeviceRegistry registry;

    setUp(() {
      registry = DeviceRegistry();
    });

    test('should be a singleton', () {
      final instance1 = DeviceRegistry();
      final instance2 = DeviceRegistry();
      expect(instance1, same(instance2));
    });

    group('Device Profiles', () {
      test('should have Weytek scale profile', () {
        final profile = registry.getProfileByServiceUuid(
          'e3b744f3-4309-4a3a-b877-ccacd9efb97d',
        );
        expect(profile, isNotNull);
        expect(profile?.name, contains('Weytek'));
        expect(profile?.type, HvacDeviceType.refrigerantScale);
        expect(profile?.manufacturer, HvacManufacturer.weytek);
        expect(profile?.unit, 'oz');
      });

      test('should have Testo T115i profile', () {
        final profile = registry.getProfileByServiceUuid(
          '0000fff0-0000-1000-8000-00805f9b34fb',
        );
        expect(profile, isNotNull);
        expect(profile?.name, contains('Testo'));
        expect(profile?.type, HvacDeviceType.temperatureProbe);
        expect(profile?.manufacturer, HvacManufacturer.testo);
      });

      test('should have ABM-200 airflow meter profile', () {
        final profile = registry.getProfileByServiceUuid(
          '961f0001-d2d6-43e3-a417-3bb8217e0e01',
        );
        expect(profile, isNotNull);
        expect(profile?.name, contains('ABM-200'));
        expect(profile?.type, HvacDeviceType.airflowMeter);
        expect(profile?.manufacturer, HvacManufacturer.weatherflow);
      });

      test('should return null for unknown service UUID', () {
        final profile = registry.getProfileByServiceUuid(
          'unknown-uuid-1234',
        );
        expect(profile, isNull);
      });
    });

    group('Device Detection', () {
      test('should detect Weytek scale by name', () {
        final profile = registry.getProfileByName('Wey-Tek HD');
        expect(profile, isNotNull);
        expect(profile?.manufacturer, HvacManufacturer.weytek);
      });

      test('should detect Testo devices by name', () {
        final profile = registry.getProfileByName('Testo T115i');
        expect(profile, isNotNull);
        expect(profile?.manufacturer, HvacManufacturer.testo);
      });

      test('should handle case-insensitive name matching', () {
        final profile1 = registry.getProfileByName('wey-tek hd');
        final profile2 = registry.getProfileByName('WEY-TEK HD');
        expect(profile1, isNotNull);
        expect(profile2, isNotNull);
      });
    });

    group('HvacDeviceType', () {
      test('should have all expected device types', () {
        expect(HvacDeviceType.values, contains(HvacDeviceType.refrigerantGauge));
        expect(HvacDeviceType.values, contains(HvacDeviceType.temperatureProbe));
        expect(HvacDeviceType.values, contains(HvacDeviceType.refrigerantScale));
        expect(HvacDeviceType.values, contains(HvacDeviceType.airflowMeter));
        expect(HvacDeviceType.values, contains(HvacDeviceType.pressureProbe));
        expect(HvacDeviceType.values, contains(HvacDeviceType.unknown));
      });
    });

    group('HvacManufacturer', () {
      test('should have all supported manufacturers', () {
        expect(HvacManufacturer.values, contains(HvacManufacturer.weytek));
        expect(HvacManufacturer.values, contains(HvacManufacturer.testo));
        expect(HvacManufacturer.values, contains(HvacManufacturer.fieldpiece));
        expect(HvacManufacturer.values, contains(HvacManufacturer.weatherflow));
        expect(HvacManufacturer.values, contains(HvacManufacturer.unknown));
      });
    });
  });

  group('Abm200Reading', () {
    test('should create valid reading', () {
      final reading = Abm200Reading(
        velocity: 500,
        tempF: 72.5,
        humidity: 45.0,
        pressure: 0.5,
      );

      expect(reading.velocity, 500);
      expect(reading.tempF, 72.5);
      expect(reading.humidity, 45.0);
      expect(reading.pressure, 0.5);
    });

    test('should have readable toString', () {
      final reading = Abm200Reading(
        velocity: 500,
        tempF: 72.5,
        humidity: 45.0,
        pressure: 0.5,
      );

      final str = reading.toString();
      expect(str, contains('500'));
      expect(str, contains('72.5'));
      expect(str, contains('45.0'));
      expect(str, contains('0.5'));
    });
  });

  group('DeviceProfile', () {
    test('should create valid profile', () {
      final profile = DeviceProfile(
        name: 'Test Device',
        manufacturer: HvacManufacturer.unknown,
        type: HvacDeviceType.unknown,
        serviceUuids: ['test-uuid'],
        unit: 'test',
      );

      expect(profile.name, 'Test Device');
      expect(profile.manufacturer, HvacManufacturer.unknown);
      expect(profile.type, HvacDeviceType.unknown);
      expect(profile.serviceUuids, contains('test-uuid'));
      expect(profile.unit, 'test');
    });
  });
}
