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

  test('armed cancellation defaults to unthrottled verification', () {
    expect(
      source,
      contains('bool enforceLockout = false'),
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
      source
          .substring(
            source.indexOf('Future<void> _recordLockout'),
            source.indexOf('Future<void> _submit'),
          )
          .contains('} catch ('),
      isFalse,
      reason:
          'No bare catch in the emergency path (project rule). _recordLockout '
          'is the bookkeeping the ARMED cancel runs, so it catches by type.',
    );
  });

  /// The sensitive-action policy (F04) legitimately needs bare catches: a
  /// counter that cannot be read OR written must deny the action, whatever the
  /// storage threw. They are confined to the `enforceLockout` branch, so the
  /// armed-cancel default never runs them -- proven behaviourally in
  /// test/core/widgets/sensitive_action_pin_gate_test.dart.
  ///
  /// This keeps the file-wide guarantee the narrower substring check above
  /// gave up: a NEW bare catch anywhere else in this gate fails the test.
  test('every bare catch is confined to the enforceLockout policy branch', () {
    final lines = source.split('\n');
    final bare = <int>[
      for (var i = 0; i < lines.length; i++)
        if (RegExp(r'\}\s*catch\s*\(').hasMatch(lines[i])) i,
    ];

    expect(
      bare.length,
      3,
      reason:
          'Exactly three: locked-state read, attempt reservation, and the '
          'post-success counter reset. A fourth is a policy change, not a '
          'refactor -- justify it here before pinning a new number.',
    );

    for (final index in bare) {
      // Walk back to whichever comes first: the guard, or the method we are in.
      var guarded = false;
      for (var i = index; i >= 0; i--) {
        if (lines[i].contains('if (widget.enforceLockout)')) {
          guarded = true;
          break;
        }
        if (RegExp(r'^  [A-Za-z].*\(').hasMatch(lines[i])) break;
      }
      expect(
        guarded,
        isTrue,
        reason:
            'Bare catch at line ${index + 1} is outside the enforceLockout '
            'branch, so an armed cancel could reach it and swallow an error '
            'while a countdown is running.',
      );
    }
  });
}
