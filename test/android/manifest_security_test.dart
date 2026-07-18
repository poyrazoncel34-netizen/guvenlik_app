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

  test('Android 12+ extraction rules exclude every app storage domain', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final rules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(rules, contains('<cloud-backup>'));
    expect(rules, contains('<device-transfer>'));
    for (final domain in [
      'root',
      'file',
      'database',
      'sharedpref',
      'external',
      'device_root',
      'device_file',
      'device_database',
      'device_sharedpref',
    ]) {
      expect(rules, contains('domain="$domain"'));
    }
  });
}
