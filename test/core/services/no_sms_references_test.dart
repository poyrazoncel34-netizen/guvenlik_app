// Test: Verify SMS references are removed from production code.
// This test enforces that the app is call-only.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('No SMS references in production code', () {
    test('health check must NOT contain sms_permission key', () {
      final file = File('lib/core/services/emergency_core_service.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains("sms_permission"),
        isFalse,
        reason: 'emergency_core_service must not report sms_permission',
      );
    });

    test('feature_warning_dialog must NOT mention SMS', () {
      final file = File('lib/core/widgets/feature_warning_dialog.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('SMS'),
        isFalse,
        reason: 'feature_warning_dialog must not mention SMS',
      );
    });

    test('legal_disclaimer_banner must NOT mention SMS', () {
      final file = File('lib/widgets/legal_disclaimer_banner.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('SMS'),
        isFalse,
        reason: 'legal_disclaimer_banner must not mention SMS',
      );
    });

    test('countdown_screen must NOT mention SMS', () {
      final file = File('lib/screens/countdown_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('SMS'),
        isFalse,
        reason: 'countdown_screen must not mention SMS',
      );
    });

    test('legal_texts.dart must NOT mention SMS', () {
      final file = File('lib/constants/legal_texts.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('SMS'),
        isFalse,
        reason: 'legal_texts must not mention SMS',
      );
    });

    test('translation files must NOT mention SMS', () {
      for (final path in [
        'assets/translations/en-US.json',
        'assets/translations/tr-TR.json',
      ]) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path must exist');
        final content = file.readAsStringSync();
        expect(
          content.contains('SMS'),
          isFalse,
          reason: '$path must not mention SMS',
        );
      }
    });
  });
}
