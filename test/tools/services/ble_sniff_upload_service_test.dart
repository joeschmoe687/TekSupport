import 'package:flutter_test/flutter_test.dart';
import 'package:tektool/tools/services/ble_sniff_upload_service.dart';

void main() {
  group('BleSniffUploadService', () {
    test('should be a singleton', () {
      final instance1 = BleSniffUploadService();
      final instance2 = BleSniffUploadService();
      expect(instance1, same(instance2));
    });

    test('should have loadSettings method', () {
      final service = BleSniffUploadService();
      expect(service.loadSettings, isA<Function>());
    });

    test('should have setAutoUploadEnabled method', () {
      final service = BleSniffUploadService();
      expect(service.setAutoUploadEnabled, isA<Function>());
    });

    test('should have setUploadAllMode method', () {
      final service = BleSniffUploadService();
      expect(service.setUploadAllMode, isA<Function>());
    });

    test('should have uploadSession method', () {
      final service = BleSniffUploadService();
      expect(service.uploadSession, isA<Function>());
    });

    test('should default to auto-upload enabled', () {
      final service = BleSniffUploadService();
      expect(service.autoUploadEnabled, true);
    });

    test('should default to upload new logs only (not all)', () {
      final service = BleSniffUploadService();
      expect(service.uploadAllMode, false);
    });

    test('should check if session is uploaded based on metadata', () {
      final service = BleSniffUploadService();
      
      final uploadedSession = {'uploaded': true};
      expect(service.isSessionUploaded(uploadedSession), true);
      
      final syncedSession = {'syncedAt': '2024-01-01T00:00:00Z'};
      expect(service.isSessionUploaded(syncedSession), true);
      
      final newSession = {'id': 'test'};
      expect(service.isSessionUploaded(newSession), false);
    });
  });
}
