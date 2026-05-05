import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Functional audit UX cleanup contracts', () {
    test('paywall and settings show feedback when external links fail', () {
      final paywall = File(
        'lib/screens/subscription/paywall_screen.dart',
      ).readAsStringSync();
      final settings = File(
        'lib/screens/settings_page.dart',
      ).readAsStringSync();
      final legalSettings = File(
        'lib/screens/settings_legal/legal_settings_screen.dart',
      ).readAsStringSync();

      expect(paywall, contains('link_open_failed'));
      expect(paywall, contains('!launched && mounted'));
      expect(settings, contains('link_open_failed'));
      expect(settings, contains('!launched && mounted'));
      expect(legalSettings, contains('link_open_failed'));
      expect(legalSettings, contains('!launched && context.mounted'));
    });

    test('fake call photo picker failure is visible to the user', () {
      final source = File(
        'lib/screens/fake_call_screen.dart',
      ).readAsStringSync();
      final picker = source.substring(source.indexOf('_pickProfileImage'));

      expect(source, contains('fake_call_photo_pick_failed'));
      expect(source, contains('_showWarningSnack'));
      expect(picker, contains('catch (_) {'));
      expect(
        picker,
        contains("_showWarningSnack('fake_call_photo_pick_failed'.tr())"),
      );
    });
  });
}
