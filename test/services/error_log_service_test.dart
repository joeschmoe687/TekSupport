import 'package:flutter_test/flutter_test.dart';
import 'package:tektool/services/error_log_service.dart';

void main() {
  group('ErrorLogService', () {
    late ErrorLogService service;

    setUp(() {
      service = ErrorLogService();
    });

    test('should be a singleton', () {
      final instance1 = ErrorLogService();
      final instance2 = ErrorLogService();
      expect(instance1, same(instance2));
    });

    group('Method Availability', () {
      test('should have initialize method', () {
        expect(service.initialize, isA<Function>());
      });

      test('should have logError method', () {
        expect(service.logError, isA<Function>());
      });
    });

    group('Error Logging Interface', () {
      test('logError should accept error parameter', () {
        // Test that the method signature is correct
        expect(
          () => service.logError('Test error'),
          returnsNormally,
        );
      });

      test('logError should accept optional stackTrace', () {
        expect(
          () => service.logError(
            'Test error',
            stackTrace: StackTrace.current,
          ),
          returnsNormally,
        );
      });

      test('logError should accept optional context', () {
        expect(
          () => service.logError(
            'Test error',
            context: 'Test context',
          ),
          returnsNormally,
        );
      });

      test('logError should accept optional additionalData', () {
        expect(
          () => service.logError(
            'Test error',
            additionalData: {'key': 'value'},
          ),
          returnsNormally,
        );
      });

      test('logError should accept all optional parameters', () {
        expect(
          () => service.logError(
            'Test error',
            stackTrace: StackTrace.current,
            context: 'Test context',
            additionalData: {'customField': 'customValue'},
          ),
          returnsNormally,
        );
      });
    });

    group('Service Initialization', () {
      test('initialize should not throw exception', () async {
        // Initialize can be called multiple times safely
        await expectLater(
          service.initialize(),
          completes,
        );
      });

      test('initialize should be idempotent (multiple calls safe)', () async {
        await service.initialize();
        await expectLater(
          service.initialize(),
          completes,
        );
      });
    });

    group('Error Handling', () {
      test('should handle errors with empty string', () {
        expect(
          () => service.logError(''),
          returnsNormally,
        );
      });

      test('should handle errors with very long messages', () {
        final longError = 'A' * 10000;
        expect(
          () => service.logError(longError),
          returnsNormally,
        );
      });

      test('should handle errors with special characters', () {
        expect(
          () => service.logError('Error: \n\t\r\$ "quotes" \'apostrophes\''),
          returnsNormally,
        );
      });

      test('should handle null additionalData values', () {
        expect(
          () => service.logError(
            'Test error',
            additionalData: {'nullValue': null},
          ),
          returnsNormally,
        );
      });

      test('should handle complex additionalData structures', () {
        expect(
          () => service.logError(
            'Test error',
            additionalData: {
              'nested': {'key': 'value'},
              'list': [1, 2, 3],
              'bool': true,
              'number': 42,
            },
          ),
          returnsNormally,
        );
      });
    });

    group('Exception Safety', () {
      test('should not crash when logging Exception object', () {
        expect(
          () => service.logError(Exception('Test exception')),
          returnsNormally,
        );
      });

      test('should not crash when logging Error object', () {
        expect(
          () => service.logError(ArgumentError('Test argument error')),
          returnsNormally,
        );
      });
    });
  });
}
