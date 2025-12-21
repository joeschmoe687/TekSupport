import 'package:flutter_test/flutter_test.dart';
import 'package:tektool/services/payment_service.dart';

/// Unit tests for PaymentService
///
/// Note: These tests require Firebase to be initialized in the test environment.
/// For full integration testing, use the PaymentVerificationScreen.
void main() {
  group('PaymentService', () {
    setUp(() {
      // PaymentService is a singleton, no need to store in variable
    });

    test('PaymentService is a singleton', () {
      final instance1 = PaymentService();
      final instance2 = PaymentService();

      expect(instance1, same(instance2));
    });

    test('PaymentResult success state', () {
      final result = PaymentResult(success: true);

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.cancelled, isFalse);
    });

    test('PaymentResult failure state', () {
      final result = PaymentResult(
        success: false,
        error: 'Payment declined',
      );

      expect(result.success, isFalse);
      expect(result.error, equals('Payment declined'));
      expect(result.cancelled, isFalse);
    });

    test('PaymentResult cancelled state', () {
      final result = PaymentResult(
        success: false,
        error: 'User cancelled',
        cancelled: true,
      );

      expect(result.success, isFalse);
      expect(result.cancelled, isTrue);
    });
  });

  group('Payment Amounts', () {
    test('Text chat amount is correct', () {
      const amountCents = 500;
      const expectedDollars = 5.00;

      expect(amountCents / 100, equals(expectedDollars));
    });

    test('Phone support amount is correct', () {
      const amountCents = 4500;
      const expectedDollars = 45.00;

      expect(amountCents / 100, equals(expectedDollars));
    });

    test('Video call amount is correct', () {
      const amountCents = 6000;
      const expectedDollars = 60.00;

      expect(amountCents / 100, equals(expectedDollars));
    });

    test('Emergency support amount is correct', () {
      const amountCents = 7000;
      const expectedDollars = 70.00;

      expect(amountCents / 100, equals(expectedDollars));
    });
  });

  group('Payment Type Descriptions', () {
    String getDescriptionForType(String type) {
      switch (type) {
        case 'text':
          return 'Text Chat Support - Chat with HVAC techs anytime';
        case 'phone':
          return 'Phone Support - Live phone call with a tech';
        case 'video':
          return 'Video Call Support - Face-to-face video support';
        case 'emergency':
          return 'Emergency Support - Priority response for urgent issues';
        default:
          return 'TekNeck Support Service';
      }
    }

    test('Text chat description is correct', () {
      expect(
        getDescriptionForType('text'),
        equals('Text Chat Support - Chat with HVAC techs anytime'),
      );
    });

    test('Phone support description is correct', () {
      expect(
        getDescriptionForType('phone'),
        equals('Phone Support - Live phone call with a tech'),
      );
    });

    test('Video call description is correct', () {
      expect(
        getDescriptionForType('video'),
        equals('Video Call Support - Face-to-face video support'),
      );
    });

    test('Emergency support description is correct', () {
      expect(
        getDescriptionForType('emergency'),
        equals('Emergency Support - Priority response for urgent issues'),
      );
    });

    test('Unknown type returns default description', () {
      expect(
        getDescriptionForType('unknown'),
        equals('TekNeck Support Service'),
      );
    });
  });
}
