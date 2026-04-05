// SmsStatusReceiver is only functional in the full flavor (ALLOW_DIRECT_SMS=true).
// It should NOT be in the main manifest to avoid dead code in the Play Store build.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SmsStatusReceiver flavor placement', () {
    test('SmsStatusReceiver must not be in main manifest', () {
      final mainManifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();

      expect(
        mainManifest,
        isNot(contains('SmsStatusReceiver')),
        reason:
            'SmsStatusReceiver is only used by the full flavor (ALLOW_DIRECT_SMS). '
            'It must not be declared in the main manifest to avoid dead code '
            'in the Play Store build.',
      );
    });
  });
}
