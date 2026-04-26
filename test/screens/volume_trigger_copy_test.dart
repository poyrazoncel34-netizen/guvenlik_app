import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Finding 2 (HIGH): the volume-button trigger is foreground-only by design,
/// but the visible copy must say so. This contract test enforces that
/// the user-facing strings include the foreground-only limitation and do
/// NOT imply background or locked-phone behavior.
void main() {
  group('Volume trigger user-visible copy is foreground-only honest', () {
    test('TR/EN settings subtitle states the foreground-only limitation', () {
      for (final entry in {
        'assets/translations/tr-TR.json': 'KoruBeni açıkken',
        'assets/translations/en-US.json': 'while KoruBeni is open',
      }.entries) {
        final json =
            jsonDecode(File(entry.key).readAsStringSync())
                as Map<String, dynamic>;
        final subtitle =
            json['settings_volume_trigger_subtitle'] as String? ?? '';
        expect(
          subtitle.toLowerCase().contains(entry.value.toLowerCase()),
          isTrue,
          reason:
              '${entry.key}:settings_volume_trigger_subtitle must contain '
              '"${entry.value}" so users know the trigger is foreground-only.',
        );
      }
    });

    test('one-time foreground-only info string exists in TR/EN', () {
      for (final path in [
        'assets/translations/tr-TR.json',
        'assets/translations/en-US.json',
      ]) {
        final json =
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
        expect(
          json.containsKey('volume_trigger_foreground_only_info'),
          isTrue,
          reason:
              '$path must define volume_trigger_foreground_only_info for the '
              'one-time SnackBar shown when the user enables the toggle.',
        );
        expect(
          (json['volume_trigger_foreground_only_info'] as String).isNotEmpty,
          isTrue,
        );
      }
    });

    test('settings_page wires the one-time info SnackBar on toggle ON', () {
      final source = File('lib/screens/settings_page.dart').readAsStringSync();
      expect(
        source.contains('volume_trigger_foreground_only_info'),
        isTrue,
        reason:
            'settings_page.dart must show the foreground-only SnackBar when '
            'the user enables the volume trigger.',
      );
    });

    test(
      'no volume-trigger marketing string implies background/locked operation',
      () {
        final keys = [
          'settings_volume_trigger_title',
          'settings_volume_trigger_subtitle',
          'subscription_value_volume_trigger',
          'premium_feature_volume_trigger',
        ];
        const forbidden = [
          'background',
          'locked',
          'kilitli',
          'arka plan',
          'screen off',
          'ekran kapalı',
        ];
        for (final path in [
          'assets/translations/tr-TR.json',
          'assets/translations/en-US.json',
        ]) {
          final json =
              jsonDecode(File(path).readAsStringSync())
                  as Map<String, dynamic>;
          for (final key in keys) {
            final value = (json[key] as String? ?? '').toLowerCase();
            for (final word in forbidden) {
              expect(
                value.contains(word),
                isFalse,
                reason:
                    '$path:$key must not imply background/locked operation '
                    '(found "$word" in "$value").',
              );
            }
          }
        }
      },
    );
  });
}
