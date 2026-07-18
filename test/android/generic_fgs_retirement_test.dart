import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generic background-service plugin and leaking wakelock are retired',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final service = File(
        'lib/core/services/foreground_service.dart',
      ).readAsStringSync();

      expect(pubspec, isNot(contains('flutter_background_service:')));
      expect(pubspec, isNot(contains('flutter_background_service_android:')));
      expect(
        manifest,
        isNot(
          contains('id.flutter.flutter_background_service.BackgroundService'),
        ),
      );
      expect(manifest, isNot(contains('FOREGROUND_SERVICE_SPECIAL_USE')));
      expect(service, isNot(contains('FlutterBackgroundService')));
      expect(service, contains('ForegroundServiceOwnership'));
    },
  );
}
