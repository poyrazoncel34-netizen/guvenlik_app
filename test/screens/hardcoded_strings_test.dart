import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settings_page.dart has no hardcoded Turkish strings', () {
    test('should not contain hardcoded Turkish UI strings', () {
      final source = File('lib/screens/settings_page.dart').readAsStringSync();
      expect(source, isNot(contains("'Gizlilik Politikası (Web)'")),
          reason: 'Privacy policy web title should use a localization key');
    });
  });

  group('pin_setup_screen.dart has no hardcoded Turkish strings', () {
    test('tooltip should use localization key not hardcoded Turkish', () {
      final source = File('lib/screens/pin_setup_screen.dart').readAsStringSync();
      expect(source, isNot(contains("tooltip: 'Yasal Bilgiler'")),
          reason: 'Legal info tooltip should use a localization key');
    });
  });
}
