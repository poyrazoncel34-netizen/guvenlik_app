// Native shake triggering is not shipped in this release. This test ensures
// SettingsProvider no longer references the deleted sensitivity model.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SettingsProvider does not reference deleted ShakeSensitivity class', () {
    final source = File(
      'lib/presentation/providers/settings_provider.dart',
    ).readAsStringSync();
    expect(
      source.contains('ShakeSensitivity'),
      isFalse,
      reason:
          'Native shake triggering is removed; SettingsProvider must not reference ShakeSensitivity',
    );
  });
}
