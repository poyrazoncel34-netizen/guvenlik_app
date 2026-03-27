// Verify that READ_PHONE_STATE permission has a prominent disclosure
// method in PermissionHelper, matching Google Play policy requirements
// for dangerous permissions.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('READ_PHONE_STATE prominent disclosure', () {
    test('PermissionHelper must have requestPhoneStatePermission method', () {
      final dartContent =
          File('lib/core/utils/permission_helper.dart').readAsStringSync();

      expect(
        dartContent,
        contains('requestPhoneStatePermission'),
        reason:
            'READ_PHONE_STATE is a dangerous permission and requires '
            'a prominent disclosure method in PermissionHelper per '
            'Google Play policy',
      );
    });
  });
}
