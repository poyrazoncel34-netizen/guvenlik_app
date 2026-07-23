import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the PIN security service may read the configured PIN', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('pin_verification_service.dart')) continue;

      final source = entity.readAsStringSync();
      final directlyReadsSecurePin = RegExp(
        r'read\s*\(\s*key:\s*SecureStorageKeys\.userPin',
        multiLine: true,
      ).hasMatch(source);
      final directlyReadsLegacyPin = RegExp(
        r'getString\s*\(\s*SecureStorageKeys\.userPin',
        multiLine: true,
      ).hasMatch(source);
      if (directlyReadsSecurePin || directlyReadsLegacyPin) {
        violations.add(entity.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Configured PIN reads must stay inside PinVerificationService so '
          'widgets and helpers never receive the stored secret.',
    );
  });
}
