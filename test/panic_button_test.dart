import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/widgets/panic_button.dart';
import 'test_helpers.dart';

void main() {
  group('PanicButton Widget', () {
    testWidgets('renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildLocalizedApp(
          const Scaffold(
            body: Center(
              child: PanicButton(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // PanicButton should exist
      expect(find.byType(PanicButton), findsOneWidget);
    });
  });
}
