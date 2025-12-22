import 'package:flutter_test/flutter_test.dart';
import 'package:tektool/services/error_log_service.dart';

void main() {
  group('ErrorLogService', () {
    test('should be a singleton', () {
      final instance1 = ErrorLogService();
      final instance2 = ErrorLogService();
      expect(instance1, same(instance2));
    });

    test('should have initialize method', () {
      final service = ErrorLogService();
      expect(service.initialize, isA<Function>());
    });

    test('should have logError method', () {
      final service = ErrorLogService();
      expect(service.logError, isA<Function>());
    });
  });
}
