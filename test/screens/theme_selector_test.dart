import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/widgets/theme_selector.dart';

void main() {
  group('ThemeSelector widget', () {
    testWidgets('renders three theme option chips', (tester) async {
      ThemeMode current = ThemeMode.dark;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ThemeSelector(
                selected: current,
                onChanged: (m) => setState(() => current = m),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey(ThemeMode.system)), findsOneWidget);
      expect(find.byKey(const ValueKey(ThemeMode.light)), findsOneWidget);
      expect(find.byKey(const ValueKey(ThemeMode.dark)), findsOneWidget);
    });
  });
}
