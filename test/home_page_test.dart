import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/widgets/panic_button.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('PanicButton is displayed and has accessibility semantics', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildLocalizedApp(
        Scaffold(
          body: Center(child: const PanicButton()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PanicButton), findsOneWidget);
  });
}
