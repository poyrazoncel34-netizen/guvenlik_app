import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/countdown_screen.dart').readAsStringSync();
  });

  test('configured PIN is never loaded into widget state', () {
    expect(source, isNot(contains('String? _correctPin')));
    expect(source, contains('PinVerificationService'));
    expect(source, contains('PinState _pinState = PinState.loading'));
    expect(source, isNot(contains('_cancelWithoutPin')));
    expect(source, isNot(contains('emergency_cancel_without_pin')));
  });

  test('widget dispose does not mutate native safety state', () {
    final disposeStart = source.indexOf('void dispose()');
    final nextMethod = source.indexOf(
      'Future<void> _cancelCountdownAndExit',
      disposeStart,
    );
    final body = source.substring(disposeStart, nextMethod);
    expect(body, isNot(contains('cancelEmergencySession')));
    expect(body, isNot(contains('cancelCountdownAlarm')));
  });

  test('UI exits only after typed cancellation acknowledgement', () {
    final cancelStart = source.indexOf('Future<void> _cancelCountdownAndExit');
    final nextMethod = source.indexOf('void _handlePinInput', cancelStart);
    final body = source.substring(cancelStart, nextMethod);
    final nativeCancel = body.indexOf('cancelEmergencySession');
    final confirmed = body.indexOf('isConfirmedCancelled');
    final activityLog = body.indexOf('ActivityService.logEvent');
    final navigatorPop = body.indexOf('Navigator.pop');
    expect(nativeCancel, isNot(-1));
    expect(confirmed, greaterThan(nativeCancel));
    expect(activityLog, greaterThan(confirmed));
    expect(navigatorPop, greaterThan(activityLog));
  });

  test('global lockout cannot block correct countdown PIN verification', () {
    final inputStart = source.indexOf('void _handlePinInput');
    final verifyStart = source.indexOf(
      'Future<void> _verifyPinAndMaybeCancel',
      inputStart,
    );
    final inputBody = source.substring(inputStart, verifyStart);
    expect(inputBody, isNot(contains('_isPinLockedOut')));
    expect(inputBody, contains('_verifyPinAndMaybeCancel'));
    final verifyEnd = source.indexOf('@override\n  Widget build', verifyStart);
    expect(
      source.substring(verifyStart, verifyEnd),
      contains('_pinVerificationService.verify'),
    );
  });
}
