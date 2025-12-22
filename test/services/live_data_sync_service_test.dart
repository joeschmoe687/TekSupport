import 'package:flutter_test/flutter_test.dart';
import 'package:tektool/services/live_data_sync_service.dart';

void main() {
  group('LiveDataSyncService', () {
    test('should be a singleton', () {
      final instance1 = LiveDataSyncService();
      final instance2 = LiveDataSyncService();
      expect(instance1, same(instance2));
    });

    test('should have init method', () {
      final service = LiveDataSyncService();
      expect(service.init, isA<Function>());
    });

    test('should have dispose method', () {
      final service = LiveDataSyncService();
      expect(service.dispose, isA<Function>());
    });

    test('should have updateConnectedDevices method', () {
      final service = LiveDataSyncService();
      expect(service.updateConnectedDevices, isA<Function>());
    });

    // Note: Full integration tests with Firebase mocks would require
    // additional setup with packages like mockito or fake_cloud_firestore.
    // These basic tests verify the service structure and singleton pattern.
  });
}
