import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Play release manifest drift guards', () {
    test(
      'source manifest removes plugin READ_CONTACTS from merged manifest',
      () {
        final source = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();

        expect(
          source,
          contains('android.permission.READ_CONTACTS'),
          reason: 'The app must explicitly remove plugin-added READ_CONTACTS.',
        );
        expect(
          source,
          contains('tools:node="remove"'),
          reason: 'Manifest merger removal must be declared in source.',
        );
      },
    );

    test(
      'source manifest removes unused geolocator location foreground service',
      () {
        final source = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();

        expect(
          source,
          contains('com.baseflow.geolocator.GeolocatorLocationService'),
          reason:
              'The unused geolocator foreground location service must be removed.',
        );
        expect(
          source.contains('android.permission.FOREGROUND_SERVICE_LOCATION'),
          isFalse,
          reason: 'The app must not declare the location FGS permission.',
        );
      },
    );
  });
}
