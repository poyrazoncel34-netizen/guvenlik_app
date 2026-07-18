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

    test('Play build removes every optional Amazon billing surface', () {
      final source = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(source, isNot(contains('com.amazon.device.iap')));
      const proxyActivity =
          'com.revenuecat.purchases.amazon.purchasing.ProxyAmazonBillingActivity';
      expect(
        source,
        contains('android:name="$proxyActivity"'),
        reason:
            'RevenueCat hybrid manifest contributes the optional proxy, so '
            'the Play source manifest must remove it explicitly.',
      );
      final activityStart = source.indexOf('android:name="$proxyActivity"');
      final activityEnd = source.indexOf('/>', activityStart);
      expect(activityEnd, greaterThan(activityStart));
      final removalDirective = source.substring(activityStart, activityEnd);
      expect(removalDirective, contains('tools:node="remove"'));
      expect(removalDirective, contains('tools:ignore="MissingClass"'));

      expect(gradle, contains('module = "purchases-store-amazon"'));
      expect(gradle, contains('module = "amazon-appstore-sdk"'));
    });

    test('Play install is limited to telephony-capable devices', () {
      final source = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(source, contains('android.permission.CALL_PHONE'));
      expect(source, contains('android.hardware.telephony'));
      expect(source, contains('android:required="true"'));
    });

    test('boot receiver is Direct Boot aware and remains non-exported', () {
      final source = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final receiverStart = source.indexOf(
        'android:name=".emergency.BootCompletedReceiver"',
      );
      expect(receiverStart, greaterThanOrEqualTo(0));
      final receiverEnd = source.indexOf('</receiver>', receiverStart);
      expect(receiverEnd, greaterThan(receiverStart));
      final receiver = source.substring(receiverStart, receiverEnd);

      expect(receiver, contains('android:directBootAware="true"'));
      expect(receiver, contains('android:exported="false"'));
      expect(receiver, contains('android.intent.action.LOCKED_BOOT_COMPLETED'));
      expect(receiver, contains('android.intent.action.BOOT_COMPLETED'));
      expect(receiver, contains('android.intent.action.MY_PACKAGE_REPLACED'));
      expect(receiver, contains('android.intent.action.USER_UNLOCKED'));
    });
  });
}
