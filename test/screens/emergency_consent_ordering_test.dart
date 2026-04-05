// Verify that CALL_PHONE permission is requested BEFORE emergency actions
// in emergency flows. Starting calls/SMS before obtaining consent for the
// full emergency action sequence violates informed consent principles.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Emergency consent ordering', () {
    test('countdown_screen requests CALL_PHONE before emergency orchestrator', () {
      final content =
          File('lib/screens/countdown_screen.dart').readAsStringSync();

      final callPermIndex =
          content.indexOf('requestCallPhonePermission');
      // New architecture uses EmergencyOrchestrator instead of SmsService directly
      final emergencyActionIndex = content.indexOf('EmergencyOrchestrator.execute');

      expect(callPermIndex, greaterThan(-1),
          reason: 'countdown_screen must request CALL_PHONE permission');
      expect(emergencyActionIndex, greaterThan(-1),
          reason: 'countdown_screen must use EmergencyOrchestrator');
      expect(
        callPermIndex,
        lessThan(emergencyActionIndex),
        reason:
            'CALL_PHONE prominent disclosure must appear BEFORE EmergencyOrchestrator.execute '
            'to ensure informed consent for the full emergency action sequence',
      );
    });
  });
}
