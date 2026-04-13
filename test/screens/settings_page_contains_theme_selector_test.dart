import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'settings_page.dart does not render a theme selector or appearance section',
    () {
      final source = File('lib/screens/settings_page.dart').readAsStringSync();
      expect(source.contains('ThemeSelector'), isFalse);
      expect(source.contains('settings_theme_section'), isFalse);
      expect(source.contains('settings_theme_title'), isFalse);
    },
  );
}
