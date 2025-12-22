import 'package:flutter_test/flutter_test.dart';
import 'package:tektool/tools/services/ble_sniff_upload_service.dart';

void main() {
  group('BleSniffUploadService', () {
    late BleSniffUploadService service;

    setUp(() {
      service = BleSniffUploadService();
    });

    test('should be a singleton', () {
      final instance1 = BleSniffUploadService();
      final instance2 = BleSniffUploadService();
      expect(instance1, same(instance2));
    });

    group('Default Settings', () {
      test('should default to auto-upload enabled', () {
        expect(service.autoUploadEnabled, true);
      });

      test('should default to upload new logs only (not all)', () {
        expect(service.uploadAllMode, false);
      });
    });

    group('Session Upload Status Detection', () {
      test('should detect uploaded session by uploaded flag', () {
        final uploadedSession = {
          'id': 'session_1',
          'uploaded': true,
          'timestamp': 1234567890,
        };
        expect(service.isSessionUploaded(uploadedSession), true);
      });

      test('should detect uploaded session by syncedAt field', () {
        final syncedSession = {
          'id': 'session_2',
          'syncedAt': '2024-01-01T00:00:00Z',
          'timestamp': 1234567890,
        };
        expect(service.isSessionUploaded(syncedSession), true);
      });

      test('should detect new session without upload markers', () {
        final newSession = {
          'id': 'session_3',
          'timestamp': 1234567890,
          'devices': [],
        };
        expect(service.isSessionUploaded(newSession), false);
      });

      test('should handle session with uploaded false', () {
        final session = {
          'id': 'session_4',
          'uploaded': false,
          'timestamp': 1234567890,
        };
        expect(service.isSessionUploaded(session), false);
      });

      test('should handle empty session data', () {
        final emptySession = <String, dynamic>{};
        expect(service.isSessionUploaded(emptySession), false);
      });

      test('should prioritize uploaded flag over missing syncedAt', () {
        final session = {
          'id': 'session_5',
          'uploaded': true,
          'syncedAt': null,
          'timestamp': 1234567890,
        };
        expect(service.isSessionUploaded(session), true);
      });
    });

    group('Method Availability', () {
      test('should have loadSettings method', () {
        expect(service.loadSettings, isA<Function>());
      });

      test('should have setAutoUploadEnabled method', () {
        expect(service.setAutoUploadEnabled, isA<Function>());
      });

      test('should have setUploadAllMode method', () {
        expect(service.setUploadAllMode, isA<Function>());
      });

      test('should have uploadSession method', () {
        expect(service.uploadSession, isA<Function>());
      });

      test('should have markSessionUploaded method', () {
        expect(service.markSessionUploaded, isA<Function>());
      });

      test('should have uploadUnsyncedSessions method', () {
        expect(service.uploadUnsyncedSessions, isA<Function>());
      });

      test('should have autoUploadSessionIfEnabled method', () {
        expect(service.autoUploadSessionIfEnabled, isA<Function>());
      });
    });

    group('Edge Cases', () {
      test('should handle session with null timestamp', () {
        final session = {
          'id': 'session_6',
          'timestamp': null,
          'devices': [],
        };
        expect(service.isSessionUploaded(session), false);
      });

      test('should handle session with extra fields', () {
        final session = {
          'id': 'session_7',
          'uploaded': true,
          'uploadedAt': '2024-01-01T00:00:00Z',
          'extraField': 'value',
          'anotherField': 123,
        };
        expect(service.isSessionUploaded(session), true);
      });
    });
  });
}
