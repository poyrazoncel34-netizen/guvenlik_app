// Verify that the foreground service type configured in Dart matches
// the AndroidManifest.xml declaration. A mismatch causes
// MissingForegroundServiceTypeException on Android 14+.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Foreground service type consistency', () {
    late String manifestContent;
    late String dartContent;

    setUpAll(() {
      manifestContent = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      dartContent = File(
        'lib/core/services/foreground_service.dart',
      ).readAsStringSync();
    });

    test(
      'Dart foregroundServiceTypes must use specialUse to match manifest declaration',
      () {
        // Manifest declares foregroundServiceType="specialUse" for BackgroundService
        expect(
          manifestContent,
          contains('android:foregroundServiceType="specialUse"'),
          reason: 'Manifest must declare specialUse foreground service type',
        );

        // Dart code must request the same type at runtime
        expect(
          dartContent,
          contains('AndroidForegroundType.specialUse'),
          reason:
              'Dart code must use AndroidForegroundType.specialUse to match manifest. '
              'Using dataSync will crash on Android 14+ with '
              'MissingForegroundServiceTypeException',
        );

        // Dart code must NOT use dataSync (mismatched with manifest)
        expect(
          dartContent,
          isNot(contains('AndroidForegroundType.dataSync')),
          reason:
              'dataSync is not declared in manifest — using it crashes on Android 14+',
        );
      },
    );
  });
}
