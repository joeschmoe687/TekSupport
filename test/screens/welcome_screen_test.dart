import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tektool/screens/welcome_screen.dart';

void main() {
  group('WelcomeScreen', () {
    testWidgets('should display welcome message and features', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WelcomeScreen(onToggleTheme: () {}),
        ),
      );

      // Check for Start Chat button
      expect(find.text('Start Chat'), findsOneWidget);

      // Check for feature bullets
      expect(
        find.textContaining('Live chat'),
        findsWidgets,
      );
      expect(
        find.textContaining('troubleshooting'),
        findsWidgets,
      );

      // Check for logo
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('should handle Start Chat button tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WelcomeScreen(onToggleTheme: () {}),
        ),
      );

      // Find and tap Start Chat button
      final chatButton = find.text('Start Chat');
      expect(chatButton, findsOneWidget);

      await tester.tap(chatButton);
      await tester.pumpAndSettle();

      // Navigation should occur (actual navigation tested in integration tests)
    });
  });
}
