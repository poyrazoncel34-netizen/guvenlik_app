import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every PIN check in the app must go through [PinVerificationService].
///
/// Two independent implementations existed: the lock screen and the settings
/// change flow both read the configured PIN into a local variable and compared
/// it with `==`, bypassing the constant-time comparator and materialising the
/// secret into widget state. A single path is the only way that stays true.
void main() {
  const pinInputSites = <String>[
    'lib/screens/app_unlock_screen.dart',
    'lib/core/utils/pin_settings_helper.dart',
  ];

  test('no PIN input site reads the configured PIN itself', () {
    for (final path in pinInputSites) {
      final source = File(path).readAsStringSync();
      expect(
        RegExp(
          r'PinVerificationService\.instance\s*\.?\s*\.?verify\(',
        ).hasMatch(source),
        isTrue,
        reason: '\$path must delegate verification to the service.',
      );
      expect(
        RegExp(r'read\(\s*key:\s*SecureStorageKeys\.userPin').hasMatch(source),
        isFalse,
        reason: '\$path must not read the configured PIN back into the UI.',
      );
    }
  });

  test('the settings flow no longer compares the PIN in plain text', () {
    final source = File(
      'lib/core/utils/pin_settings_helper.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('oldController.text != currentPin')));
    expect(source, isNot(contains('newController.text == currentPin')));
    expect(source, contains('currentCheck.matches'));
    expect(source, contains('reuseCheck.matches'));
  });

  test('a storage read failure is never reported as a wrong PIN', () {
    for (final path in pinInputSites) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('PinState.readFailed'),
        reason:
            '$path must separate "cannot read the PIN" from "wrong PIN"; '
            'conflating them consumes lockout attempts for a storage fault.',
      );
    }
  });

  test('the constant-time comparator is still the only comparison', () {
    final service = File(
      'lib/core/services/pin_verification_service.dart',
    ).readAsStringSync();

    expect(service, contains('_constantTimeEquals(candidate,'));
    expect(service, contains('bool _constantTimeEquals('));
  });
}
