// READ_PHONE_STATE is declared for exactly one purpose: choosing the SIM
// account an emergency call is placed on (dual-SIM "ask every time" would
// otherwise park the call in Telecom's SIM picker). These pins keep it from
// quietly growing into phone-number, device-ID or Fake Call access.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('READ_PHONE_STATE policy surface', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    test(
      'manifest declares READ_PHONE_STATE with its SIM-selection reason',
      () {
        expect(manifest, contains('android.permission.READ_PHONE_STATE'));
        expect(manifest, contains('choose the SIM account an'));
      },
    );

    test('manifest does not widen the phone group beyond the call path', () {
      // permission_handler's Permission.phone requests every phone-group
      // permission found in the manifest in one dialog.
      for (final name in const [
        'READ_PHONE_NUMBERS',
        'READ_CALL_LOG',
        'WRITE_CALL_LOG',
        'ANSWER_PHONE_CALLS',
        'PROCESS_OUTGOING_CALLS',
      ]) {
        expect(
          manifest,
          isNot(contains('android.permission.$name')),
          reason: name,
        );
      }
    });

    test('only the SIM account source reads phone state', () {
      final kotlinRoot = Directory('android/app/src/main/kotlin');
      final readers = <String>[];
      final phoneStateApi = RegExp(
        r'getDefaultOutgoingPhoneAccount|callCapablePhoneAccounts|'
        r'activeSubscriptionInfoList|getLine1Number|getImei|getDeviceId|'
        r'getSubscriberId|getSimSerialNumber',
      );
      for (final file in kotlinRoot.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.kt')) {
          if (phoneStateApi.hasMatch(file.readAsStringSync())) {
            readers.add(file.uri.pathSegments.last);
          }
        }
      }
      expect(readers, ['AndroidPhoneAccountSource.kt']);
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
            'the phone group stays scoped to the emergency call flow only.',
      );
    });
  });
}
