import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvac_support_app/screens/home_screen.dart';

void main() {
  testWidgets('Home screen shows welcome text and chat button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(onToggleTheme: () {})),
    );

    // Check for welcome text
    expect(
      find.text('Expert HVAC help—right when you need it.'),
      findsOneWidget,
    );

    // Check for chat button
    expect(find.text('Start Chat'), findsOneWidget);

    // Check if logo appears
    expect(find.byType(Image), findsWidgets);
  });
}
