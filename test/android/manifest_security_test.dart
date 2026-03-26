import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// S2: AndroidManifest must explicitly disable backup to prevent sensitive data
/// extraction via adb backup (contacts, emergency settings, activity logs).
void main() {
  test('AndroidManifest should disable allowBackup', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest.contains('android:allowBackup="false"'),
      isTrue,
      reason:
          'AndroidManifest must set android:allowBackup="false" to prevent '
          'sensitive data extraction via adb backup',
    );
  });
}
