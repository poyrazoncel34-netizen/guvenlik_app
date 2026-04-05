import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings_page.dart renders ThemeSelector in theme section', () {
    final source = File('lib/screens/settings_page.dart').readAsStringSync();
    expect(
      source.contains('ThemeSelector'),
      isTrue,
      reason: 'settings_page.dart must use ThemeSelector widget in the Appearance section',
    );
  });
}
