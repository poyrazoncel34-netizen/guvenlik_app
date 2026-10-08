import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import 'emergency_platform_service.dart';

/// elapsedRealtime (ms) and the boot it belongs to, from native.
typedef MonotonicReading = ({int elapsedMs, int bootCount});

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
  PinLockoutService._({
    Future<MonotonicReading?> Function()? monotonic,
    DateTime Function()? now,
  }) : _monotonic =
           monotonic ?? EmergencyPlatformService.instance.readMonotonicClock,
       _now = now ?? DateTime.now;

  static final PinLockoutService instance = PinLockoutService._();

  @visibleForTesting
  factory PinLockoutService.forTesting({
    required Future<MonotonicReading?> Function() monotonic,
    required DateTime Function() now,
  }) => PinLockoutService._(monotonic: monotonic, now: now);

  final Future<MonotonicReading?> Function() _monotonic;
  final DateTime Function() _now;

  static const String _failedAttemptsKey = 'pin_lockout_failed_attempts';
  static const String _lockedUntilKey = 'pin_lockout_until_ms';
  // The same deadline on elapsedRealtime, and the boot it belongs to (Y-05).
  static const String _lockedUntilElapsedKey = 'pin_lockout_until_elapsed_ms';
  static const String _lockedBootKey = 'pin_lockout_boot_count';
  static const int _unknownBoot = -1;

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
    if (lockedUntilMs == null) {
      return PinLockoutReadable(
        PinLockoutState(failedAttempts: failedAttempts, lockedUntil: null),
      );
    }
    final remaining = await _remaining(
      DateTime.fromMillisecondsSinceEpoch(lockedUntilMs),
    );
    return PinLockoutReadable(
      PinLockoutState(
        failedAttempts: failedAttempts,
        lockedUntil: remaining > Duration.zero
            ? DateTime.now().add(remaining)
            : null,
      ),
    );
  }

  /// Time left on a lockout (audit Y-05).
  ///
  /// The wall deadline alone let a user-set clock end a lockout at once
  /// (+1 h: an 86 s lockout gone) or stretch it (-2 h: 7431 s). Within the
  /// boot that set it, elapsedRealtime -- which nobody can set -- decides;
  /// across a reboot, or without a reading, the wall deadline still counts but
  /// never for longer than the longest lockout the policy can impose.
  Future<Duration> _remaining(DateTime wallUntil) async {
    final elapsedUntil = int.tryParse(
      await _secureStorage.read(key: _lockedUntilElapsedKey) ?? '',
    );
    final boot = int.tryParse(
      await _secureStorage.read(key: _lockedBootKey) ?? '',
    );
    final reading = elapsedUntil != null && boot != null && boot != _unknownBoot
        ? await _readMonotonic()
        : null;
    final left = reading != null && reading.bootCount == boot
        ? Duration(milliseconds: elapsedUntil! - reading.elapsedMs)
        : wallUntil.difference(_now());
    const cap = Duration(seconds: maxLockoutSeconds);
    return left > cap ? cap : left;
  }

  Future<MonotonicReading?> _readMonotonic() async {
    try {
      return await _monotonic();
    } on Exception {
      return null;
    }
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
      lockedUntil = _now().add(Duration(seconds: seconds));
      final reading = await _readMonotonic();
      await _secureStorage.write(
        key: _lockedUntilKey,
        value: '${lockedUntil.millisecondsSinceEpoch}',
      );
      if (reading != null && reading.bootCount != _unknownBoot) {
        await _secureStorage.write(
          key: _lockedUntilElapsedKey,
          value: '${reading.elapsedMs + seconds * 1000}',
        );
        await _secureStorage.write(
          key: _lockedBootKey,
          value: '${reading.bootCount}',
        );
      } else {
        await _clearMonotonicDeadline();
      }
    } else {
      await _secureStorage.delete(key: _lockedUntilKey);
      await _clearMonotonicDeadline();
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
      _secureStorage.delete(key: _lockedUntilElapsedKey),
      _secureStorage.delete(key: _lockedBootKey),
    ]);
  }

  Future<void> _clearMonotonicDeadline() async {
    await _secureStorage.delete(key: _lockedUntilElapsedKey);
    await _secureStorage.delete(key: _lockedBootKey);
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
