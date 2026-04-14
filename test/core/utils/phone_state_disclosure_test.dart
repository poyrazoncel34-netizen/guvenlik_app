// Verify that READ_PHONE_STATE is not part of the Google Play build surface.
// Fake Call is an on-device simulation and must not trigger phone-state access.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('READ_PHONE_STATE policy surface', () {
    test('Android manifest must not declare READ_PHONE_STATE', () {
      final manifestContent = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifestContent, isNot(contains('READ_PHONE_STATE')));
    });

    test('PermissionHelper must not request phone-state permission', () {
      final dartContent = File(
        'lib/core/utils/permission_helper.dart',
      ).readAsStringSync();

      expect(
        dartContent,
        isNot(contains('requestPhoneStatePermission')),
        reason:
            'Fake Call does not need READ_PHONE_STATE in this Play release; '
            'CALL_PHONE must remain scoped to the emergency flow only.',
      );
    });
  });
}
