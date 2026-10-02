import 'dart:async';
import 'dart:math';

import '../di/service_locator.dart';
import '../security/secure_storage.dart';

class PinLockoutState {
  final int failedAttempts;
  final DateTime? lockedUntil;

  const PinLockoutState({
    required this.failedAttempts,
    required this.lockedUntil,
  });

  bool get isLocked =>
      lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  int get remainingSeconds {
    if (!isLocked || lockedUntil == null) {
      return 0;
    }
    final remaining = lockedUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }
}

/// The outcome of reading the brute-force counters.
///
/// Sealed so the compiler refuses a caller that forgets the unreadable case.
/// That case is the whole reason this type exists: treating an unreadable
/// counter as "zero failures, not locked" silently disarms the only thing
/// enforcing the PIN lockout.
sealed class PinLockoutRead {
  const PinLockoutRead();
}

/// The counters were read and are trustworthy.
final class PinLockoutReadable extends PinLockoutRead {
  const PinLockoutReadable(this.state);

  final PinLockoutState state;
}

/// The counters hold values this service will not interpret -- a negative
/// count, a non-numeric attempt total, an unparseable deadline. NOT a storage
/// fault: those still throw, because an exception is the right shape for an
/// error that is nobody's data.
final class PinLockoutUnreadable extends PinLockoutRead {
  const PinLockoutUnreadable();
}

class PinLockoutService {
  PinLockoutService._();

  static final PinLockoutService instance = PinLockoutService._();

  static const String _failedAttemptsKey = 'pin_lockout_failed_attempts';
  static const String _lockedUntilKey = 'pin_lockout_until_ms';

  /// Consecutive failures that trigger the first lockout.
  static const int lockoutThreshold = 5;

  /// First lockout length, applied at the [lockoutThreshold]th consecutive failure.
  static const int baseLockoutSeconds = 30;

  /// Hard ceiling for the exponential backoff.
  ///
  /// Uncapped doubling reached 8.5 hours at 15 failures and ~11 days at 20,
  /// which locks a panicking owner out of their own safety app, and past ~44
  /// failures the computed duration overflowed into the past and disabled the
  /// lockout entirely. A capped window keeps brute force impractical
  /// (9,984 admissible 4-digit PINs at one attempt per 15 minutes) while
  /// remaining survivable for the legitimate user.
  static const int maxLockoutSeconds = 15 * 60;

  /// Pure, testable backoff: 30s, 60s, 120s ... capped at [maxLockoutSeconds].
  static int lockoutSecondsFor(int failedAttempts) {
    if (failedAttempts < lockoutThreshold) return 0;
    final exponent = failedAttempts - lockoutThreshold;
    // Stop doubling before the value can leave the int range; the cap applies
    // long before this bound, so the clamp is a safety net, not the policy.
    if (exponent >= 32) return maxLockoutSeconds;
    final seconds = baseLockoutSeconds * pow(2, exponent).toInt();
    return seconds > maxLockoutSeconds ? maxLockoutSeconds : seconds;
  }

  SecureStorage get _secureStorage => serviceLocator<SecureStorage>();

  /// Reads the brute-force counters.
  ///
  /// Corrupt stored values are NOT an exception. They are an expected outcome of
  /// reading data this process does not control, so they come back as
  /// [PinLockoutUnreadable] and the compiler makes every caller answer for them.
  ///
  /// This used to `throw StateError`, which forced both call sites to catch an
  /// `Error` subtype -- something the Dart style rules forbid, because catching
  /// `Error` also swallows real bugs. Removing the catch was not an option
  /// either: nothing else enforces the lockout, so an unhandled corrupt counter
  /// would have silently disarmed it. Making the expected failure part of the
  /// RETURN TYPE removes the dilemma instead of picking a side of it.
  ///
  /// Storage faults still throw. `PlatformException` from flutter_secure_storage
  /// is input, not a bug, and callers catch it with `on Exception`.
  Future<PinLockoutRead> readState() async {
    final failedRaw = await _secureStorage.read(key: _failedAttemptsKey);
    final lockedUntilRaw = await _secureStorage.read(key: _lockedUntilKey);
    final failedAttempts = int.tryParse(failedRaw ?? '') ?? 0;
    final lockedUntilMs = int.tryParse(lockedUntilRaw ?? '');
    if ((failedRaw != null && (int.tryParse(failedRaw) == null || failedAttempts < 0)) ||
        (lockedUntilRaw != null && lockedUntilMs == null)) {
      return const PinLockoutUnreadable();
    }
    final lockedUntil = lockedUntilMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lockedUntilMs);

    if (lockedUntil != null && DateTime.now().isAfter(lockedUntil)) {
      return PinLockoutReadable(
        PinLockoutState(failedAttempts: failedAttempts, lockedUntil: null),
      );
    }

    return PinLockoutReadable(
      PinLockoutState(
        failedAttempts: failedAttempts,
        lockedUntil: lockedUntil,
      ),
    );
  }

  /// Debits one failed attempt.
  ///
  /// An unreadable counter is treated as "the real count is unknown", and the
  /// attempt is debited from the base threshold rather than from zero: a corrupt
  /// counter must never buy the attacker a fresh set of free guesses.
  Future<PinLockoutState> registerFailure() async {
    final read = await readState();
    final current = switch (read) {
      PinLockoutReadable(:final state) => state,
      PinLockoutUnreadable() => const PinLockoutState(
        failedAttempts: lockoutThreshold - 1,
        lockedUntil: null,
      ),
    };
    final failedAttempts = current.failedAttempts + 1;

    DateTime? lockedUntil;
    if (failedAttempts >= lockoutThreshold) {
      final seconds = lockoutSecondsFor(failedAttempts);
      lockedUntil = DateTime.now().add(Duration(seconds: seconds));
      await _secureStorage.write(
        key: _lockedUntilKey,
        value: '${lockedUntil.millisecondsSinceEpoch}',
      );
    } else {
      await _secureStorage.delete(key: _lockedUntilKey);
    }

    await _secureStorage.write(
      key: _failedAttemptsKey,
      value: '$failedAttempts',
    );

    return PinLockoutState(
      failedAttempts: failedAttempts,
      lockedUntil: lockedUntil,
    );
  }

  Future<void> reset() async {
    await Future.wait([
      _secureStorage.delete(key: _failedAttemptsKey),
      _secureStorage.delete(key: _lockedUntilKey),
    ]);
  }

  /// Ticks the remaining lockout seconds for a screen that is already locked.
  ///
  /// Stops on an unreadable counter rather than guessing: the band stays, and
  /// the screen re-reads on the next entry. Re-polling a store that just failed
  /// only reproduces the failure on a timer.
  Stream<int> countdownStream(PinLockoutState initial) async* {
    var state = initial;
    while (state.isLocked) {
      yield state.remainingSeconds;
      await Future<void>.delayed(const Duration(seconds: 1));
      final read = await readState();
      if (read is! PinLockoutReadable) return;
      state = read.state;
    }
    yield 0;
  }
}
