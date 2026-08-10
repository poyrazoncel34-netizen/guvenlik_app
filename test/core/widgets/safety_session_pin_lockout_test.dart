import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every PIN entry point must feed the same failure counter.
///
/// AppUnlockScreen locked out after repeated failures, but the safety-session
/// gate -- which cancels or extends an ARMED session -- verified the same four
/// digits with no bookkeeping at all. Someone holding an unlocked phone could
/// brute-force it and leave no trace anywhere.
///
/// This gate records but deliberately does NOT block: it stands in front of a
/// user trying to stop a countdown that is already running, and locking them
/// out of their own cancel would be worse than the attack it prevents.
void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/core/widgets/safety_session_pin_gate.dart',
    ).readAsStringSync();
  });

  test('a wrong PIN is recorded against the shared lockout counter', () {
    expect(
      source,
      contains('PinLockoutService.instance.registerFailure()'),
      reason: 'Unlimited untracked attempts were the hole this closes.',
    );
    expect(
      source,
      contains('PinLockoutService.instance.reset()'),
      reason:
          'A successful cancel must clear the counter, or a legitimate user '
          'ends up one mistake away from a locked app.',
    );
  });

  test('the gate never blocks or throttles on the lockout state', () {
    expect(
      source.contains('isLocked'),
      isFalse,
      reason:
          'Blocking here would stop a user from cancelling a countdown that '
          'is already dialing. Record, do not block.',
    );
  });

  test('lockout bookkeeping cannot break the cancel dialog', () {
    expect(
      source,
      contains('on StateError catch'),
      reason:
          'A missing or faulting lockout dependency must degrade to an '
          'unrecorded attempt, never to a dialog that throws while an armed '
          'session is counting down.',
    );
    expect(
      source.contains('} catch ('),
      isFalse,
      reason: 'No bare catch in the emergency path (project rule).',
    );
  });
}
