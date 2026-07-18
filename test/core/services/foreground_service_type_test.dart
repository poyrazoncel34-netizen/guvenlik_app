import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generic specialUse foreground service is absent from Play manifest',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final dart = File(
        'lib/core/services/foreground_service.dart',
      ).readAsStringSync();

      expect(manifest, isNot(contains('FOREGROUND_SERVICE_SPECIAL_USE')));
      expect(manifest, isNot(contains('foregroundServiceType="specialUse"')));
      expect(dart, isNot(contains('AndroidForegroundType')));
      expect(dart, contains('exact + inexact'));
    },
  );
}
