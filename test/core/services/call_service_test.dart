import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/call_service.dart';

/// M3: Phone number validation — numbers shorter than 7 digits should fail.
/// H4: Consent gate should not block emergency calls.
/// CallService.callTimeout must exist for plugin safety.
void main() {
  test(
    'startEmergencyCall rejects phone numbers shorter than 7 digits',
    () async {
      final result = await CallService.startEmergencyCall('123');
      expect(result.isSuccess, isFalse);
      expect(result.status, EmergencyCallStatus.failed);
      expect(result.number, '123');
    },
  );

  test(
    'startEmergencyCall returns failed (never 112) when no number is configured',
    () async {
      final result = await CallService.startEmergencyCall('');
      expect(result.status, EmergencyCallStatus.failed);
      expect(result.isFailed, isTrue);
      expect(
        result.number,
        isNot('112'),
        reason: 'Empty target must NOT be coerced to 112.',
      );
    },
  );

  test(
    'CALL_PHONE direct path is permission-gated and falls back to dialer',
    () {
      final source = File(
        'lib/core/services/call_service.dart',
      ).readAsStringSync();
      final permissionCheck = source.indexOf('Permission.phone.status');
      final directCall = source.indexOf('FlutterDirectCallerPlugin.callNumber');
      final dialerFallback = source.indexOf('AndroidIntentService.openDialer');

      expect(permissionCheck, isNot(-1));
      expect(directCall, isNot(-1));
      expect(dialerFallback, isNot(-1));
      expect(permissionCheck < directCall, isTrue);
      expect(directCall < dialerFallback, isTrue);
      expect(source, isNot(contains('Permission.phone.request()')));
    },
  );

  test('permanently denied phone permission shows manual/settings copy', () {
    final helper = File(
      'lib/core/utils/permission_helper.dart',
    ).readAsStringSync();
    final en = File('assets/translations/en-US.json').readAsStringSync();
    final tr = File('assets/translations/tr-TR.json').readAsStringSync();

    expect(helper, contains('status.isPermanentlyDenied'));
    expect(helper, contains('perm_call_denied_title'));
    expect(helper, contains('perm_call_denied_msg'));
    expect(helper, contains('openAppSettings'));
    expect(en, contains('Direct emergency calling is disabled'));
    expect(tr, contains('Doğrudan acil arama Android ayarlarında kapalı'));
  });

  test('countdown / panic flow no longer synthesizes 112', () {
    final countdown = File(
      'lib/screens/countdown_screen.dart',
    ).readAsStringSync();
    final receiver = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CountdownAlarmReceiver.kt',
    ).readAsStringSync();

    // 112 removed from ALL flows: neither the Dart panic path nor its native
    // backup may fall back to / coerce to 112.
    expect(
      countdown.contains('AppConstants.turkeyEmergencyNumber'),
      isFalse,
      reason: 'Countdown/panic must not synthesize 112 as a target.',
    );
    expect(
      receiver.contains('?: "112"'),
      isFalse,
      reason: 'Countdown native backup must not fall back to 112.',
    );
  });

  test('check-in escalation never falls back to 112 (SPEC §0 K1/K2)', () {
    final checkIn = File(
      'lib/core/services/check_in_service.dart',
    ).readAsStringSync();

    // Check-in / safe-walk expiry calls ONLY the primary contact — no 112
    // default. Empty primary -> no call (handled by resolvePrimaryNumber).
    expect(
      checkIn.contains('AppConstants.turkeyEmergencyNumber'),
      isFalse,
      reason: 'Check-in must not synthesize 112 as an escalation target.',
    );
    expect(checkIn, contains('resolvePrimaryNumber('));
  });

  test('CallService has a call timeout constant for plugin safety', () {
    expect(CallService.callTimeout, isA<Duration>());
    expect(CallService.callTimeout.inSeconds, lessThanOrEqualTo(5));
  });
}
