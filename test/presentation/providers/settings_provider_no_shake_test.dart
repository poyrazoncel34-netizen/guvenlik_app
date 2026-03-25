// ShakeDetectorService was removed from main in #16. This test ensures
// SettingsProvider no longer references the deleted ShakeSensitivity class.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SettingsProvider does not reference deleted ShakeSensitivity class', () {
    final source = File('lib/presentation/providers/settings_provider.dart').readAsStringSync();
    expect(
      source.contains('ShakeSensitivity'),
      isFalse,
      reason: 'ShakeDetectorService was removed — SettingsProvider must not reference ShakeSensitivity',
    );
  });
}
