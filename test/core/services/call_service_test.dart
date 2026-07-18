import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/call_service.dart';

/// The Dart layer contains presentation-only outcomes. Native Telecom and the
/// typed safety coordinator are the sole automatic request authority.
void main() {
  test('outcome model never promotes a request to a confirmed call', () {
    final requested = EmergencyCallResult.requested('+905551234567');
    final dialer = EmergencyCallResult.dialer('+905551234567');
    final failed = EmergencyCallResult.failed('');

    expect(requested.isConfirmed, isFalse);
    expect(requested.requiresVerification, isTrue);
    expect(dialer.isConfirmed, isFalse);
    expect(dialer.requiresUserAction, isTrue);
    expect(failed.isFailed, isTrue);
    expect(failed.number, isNot('112'));
  });

  test('Dart has no independent direct-call authority', () {
    final source = File(
      'lib/core/services/call_service.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(source, isNot(contains('class CallService')));
    expect(source, isNot(contains('FlutterDirectCallerPlugin')));
    expect(source, isNot(contains('Permission.phone')));
    expect(pubspec, isNot(contains('flutter_direct_caller_plugin')));
  });

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
    expect(en, contains('Automatic call-request submission is disabled'));
    expect(tr, contains('Otomatik arama isteği Android ayarlarında kapalı'));
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
}
