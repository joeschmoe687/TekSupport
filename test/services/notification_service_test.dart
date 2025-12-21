import 'package:flutter_test/flutter_test.dart';
import 'package:tektool/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    test('should be a singleton', () {
      final instance1 = NotificationService();
      final instance2 = NotificationService();
      expect(instance1, same(instance2));
    });

    test('should have initialize method', () {
      final service = NotificationService();
      expect(service.initialize, isA<Function>());
    });
  });
}
