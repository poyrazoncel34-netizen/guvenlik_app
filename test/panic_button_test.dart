import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/widgets/panic_button.dart';

void main() {
  group('PanicButton Widget', () {
    testWidgets('renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PanicButton(),
            ),
          ),
        ),
      );

      // PanicButton should exist
      expect(find.byType(PanicButton), findsOneWidget);
    });
  });
}
