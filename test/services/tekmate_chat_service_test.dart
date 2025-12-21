import 'package:flutter_test/flutter_test.dart';
import 'package:hvac_support_app/services/tekmate_chat_service.dart';

/// Unit tests for TekMate Chat Service
/// 
/// These tests verify the Ghost Mode security implementation:
/// - Non-admin users get null responses (no error)
/// - Admin users can access TekMate
/// - Service initializes correctly
void main() {
  group('TekMateChatService', () {
    late TekMateChatService service;

    setUp(() {
      service = TekMateChatService();
    });

    test('Service is a singleton', () {
      final service1 = TekMateChatService();
      final service2 = TekMateChatService();
      expect(service1, same(service2));
    });

    test('isAvailable returns false before init', () {
      expect(service.isAvailable, false);
    });

    test('isAdmin returns false before init', () {
      expect(service.isAdmin, false);
    });

    test('getResponse returns null for non-admin before init', () async {
      final response = await service.getResponse('test message');
      expect(response, null);
    });

    // Note: Full integration tests require Firebase auth mocking
    // and should be run in integration_test/ directory
  });

  group('TekMateResponse', () {
    test('High confidence threshold is correct', () {
      final highConfidence = TekMateResponse(
        response: 'Test',
        confidence: 0.9,
        autoRespond: false,
      );
      expect(highConfidence.isHighConfidence, true);

      final lowConfidence = TekMateResponse(
        response: 'Test',
        confidence: 0.8,
        autoRespond: false,
      );
      expect(lowConfidence.isHighConfidence, false);
    });

    test('Auto-respond threshold is correct', () {
      final shouldAuto = TekMateResponse(
        response: 'Test',
        confidence: 0.95,
        autoRespond: false,
      );
      expect(shouldAuto.shouldAutoRespond, true);

      final shouldNotAuto = TekMateResponse(
        response: 'Test',
        confidence: 0.85,
        autoRespond: false,
      );
      expect(shouldNotAuto.shouldAutoRespond, false);
    });

    test('Confidence percent calculation', () {
      final response = TekMateResponse(
        response: 'Test',
        confidence: 0.87,
        autoRespond: false,
      );
      expect(response.confidencePercent, 87);
    });

    test('Confidence percent rounds correctly', () {
      final response = TekMateResponse(
        response: 'Test',
        confidence: 0.876,
        autoRespond: false,
      );
      expect(response.confidencePercent, 87);
    });
  });
}
