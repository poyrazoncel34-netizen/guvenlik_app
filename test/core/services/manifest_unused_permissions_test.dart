// Verify that no foreground service permissions are declared without
// a corresponding foregroundServiceType in a <service> element.
// Unused FGS permissions are flagged by Play Store automated review.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Manifest unused FGS permissions', () {
    test(
      'FOREGROUND_SERVICE_LOCATION must not be declared if no service uses location type',
      () {
        final manifestContent = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();

        final hasLocationFgsPermission = manifestContent.contains(
          'android.permission.FOREGROUND_SERVICE_LOCATION',
        );
        final hasLocationServiceType = manifestContent.contains(
          'android:foregroundServiceType="location"',
        );

        // If the permission is declared, there must be a service using it
        if (hasLocationFgsPermission) {
          expect(
            hasLocationServiceType,
            isTrue,
            reason:
                'FOREGROUND_SERVICE_LOCATION permission is declared but no '
                'service uses foregroundServiceType="location". '
                'Remove the unused permission to avoid Play Store rejection.',
          );
        }
      },
    );
  });
}
