import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import 'emergency_session_contract.dart';
import 'pin_lockout_service.dart';

/// What a countdown's PIN pad does around the comparison itself.
///
/// Extracted from `countdown_screen.dart` (accepted size debt).
///
/// Y-06 (chaos audit 2026-10-08): the rehearsal pad debited wrong PINs into
/// the real lockout but never ASKED it. On an API 35 emulator five rehearsal
/// misses locked the app ("Kilitli: 17s"), and the same rehearsal pad then
/// accepted the right PIN during that lockout -- an unthrottled PIN oracle for
/// whoever holds the unlocked phone. A REAL countdown deliberately keeps
/// verifying while locked: a locked-out owner must still be able to stop an
/// emergency call (each guess there also costs a call).
final class CountdownPinMeter {
  CountdownPinMeter({PinLockoutService? lockout})
    : _lockout = lockout ?? PinLockoutService.instance;

  final PinLockoutService _lockout;
  DateTime? _lastWrongEvaluation;

  /// Why a REHEARSAL must not verify an entry right now, or null when it may.
  /// An unreadable counter refuses too: a rehearsal has no call to stop.
  Future<String?> rehearsalRefusal() async {
    try {
      return switch (await _lockout.readState()) {
        PinLockoutUnreadable() => 'pin_state_read_failed'.tr(),
        PinLockoutReadable(:final state) =>
          state.isLocked
              ? 'brute_force_locked'.tr(
                  namedArgs: {'seconds': '${state.remainingSeconds}'},
                )
              : null,
      };
    } on Exception {
      return 'pin_state_read_failed'.tr();
    }
  }

  /// Debits a mismatch against the real lockout, at most once per second: a
  /// pad that registers one entry twice must not cost the user two attempts.
  Future<void> recordMiss(PinState state) async {
    final now = DateTime.now();
    final evaluate =
        state == PinState.configured &&
        (_lastWrongEvaluation == null ||
            now.difference(_lastWrongEvaluation!) >=
                const Duration(seconds: 1));
    if (!evaluate) return;
    _lastWrongEvaluation = now;
    await _lockout.registerFailure().catchError((Object error) {
      debugPrint('PinLockoutService.registerFailure failed: $error');
      return const PinLockoutState(failedAttempts: 0, lockedUntil: null);
    });
  }
}
