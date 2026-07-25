import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The lock screen runs BEFORE authentication, so anything it can do is
/// something an attacker holding the device can do without the PIN.
void main() {
  late String source;

  setUp(() {
    source = File('lib/screens/app_unlock_screen.dart').readAsStringSync();
  });

  test('the destructive reset is refused while a safety session is live', () {
    expect(source, contains('SafetySessionActivityProbe.instance'));
    expect(source, contains('hasActiveSession()'));
    expect(source, contains('forgot_pin_blocked_active_session'));

    final guardIndex = source.indexOf('hasActiveSession()');
    final resetIndex = source.indexOf('AppResetService.clearLocalData()');
    expect(guardIndex, greaterThan(-1));
    expect(resetIndex, greaterThan(-1));
    expect(
      guardIndex,
      lessThan(resetIndex),
      reason:
          'The active-session guard must run before the wipe, otherwise an '
          'attacker cancels an ARMED session and deletes the contacts with '
          'three taps and no PIN.',
    );
  });

  test('the configured PIN is never copied into widget state', () {
    expect(
      source,
      isNot(contains('String? _correctPin')),
      reason: 'A plaintext PIN in State survives in heap dumps.',
    );
    expect(source, isNot(contains('_pin == _correctPin')));
    expect(source, contains('PinVerificationService.instance.verify('));
    expect(
      source,
      isNot(contains('SecureStorageKeys.userPin')),
      reason: 'The screen must not read the PIN itself; the service owns it.',
    );
  });

  test('a storage read failure is not treated as a wrong PIN', () {
    expect(source, contains('PinState.readFailed'));
    expect(source, contains('pin_state_read_failed'));
  });

  test('recovery stays reachable while the lockout window is running', () {
    expect(
      source,
      isNot(contains('onPressed: _isLockedOut ? null : _showForgotPinDialog')),
      reason:
          'A locked-out owner who forgot the PIN had no escape path at all '
          'while the exponential window ran.',
    );
  });
}
