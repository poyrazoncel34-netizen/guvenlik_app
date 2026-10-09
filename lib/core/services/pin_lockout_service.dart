import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import 'emergency_platform_service.dart';

/// elapsedRealtime (ms) and the boot it belongs to, from native: BOOT_COUNT
/// (-1 when unreadable) and the kernel boot id (null when unreadable).
typedef MonotonicReading = ({int elapsedMs, int bootCount, String? bootId});

extension MonotonicBoot on MonotonicReading {
  /// Whether this reading is provably from the boot identified by [count] and
  /// [id], in the native coordinator's order (A-02r): the kernel id when both
  /// sides have one -- unique per boot by construction -- else BOOT_COUNT
  /// when both know it. Unprovable is "not the same boot".
  bool isSameBootAs(int count, String? id) {
    final own = bootId;
    if (own != null && id != null) return own == id;
    return bootCount != -1 && count != -1 && bootCount == count;
  }
}

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
    bool Function()? monotonicRequired,
  }) : _monotonic =
           monotonic ?? EmergencyPlatformService.instance.readMonotonicClock,
       _now = now ?? DateTime.now,
       _monotonicRequired = monotonicRequired ?? _bridgePresent;

  static final PinLockoutService instance = PinLockoutService._();

  @visibleForTesting
  factory PinLockoutService.forTesting({
    required Future<MonotonicReading?> Function() monotonic,
    required DateTime Function() now,
    bool Function()? monotonicRequired,
  }) => PinLockoutService._(
    monotonic: monotonic,
    now: now,
    monotonicRequired: monotonicRequired,
  );

  final Future<MonotonicReading?> Function() _monotonic;
  final DateTime Function() _now;

  /// Whether a failed monotonic read is a transient fault (true) rather than
  /// a platform with no monotonic clock at all. Asked only after a read failed.
  final bool Function() _monotonicRequired;

  static bool _bridgePresent() {
    final platform = EmergencyPlatformService.instance;
    return platform.isSupported && !platform.platformBridgeMissing;
  }

  /// Serializes [readState], [registerFailure] and [reset]: a read that found
  /// a lockout expired must not delete the keys of one registered meanwhile.
  /// An idle service runs the call at once: chaining every call onto the last
  /// one's future would tie this singleton to whichever zone ran it first.
  bool _busy = false;
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();
  Future<T> _serialized<T>(Future<T> Function() body) async {
    if (_busy) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    _busy = true;
    try {
      return await body();
    } finally {
      if (_waiting.isEmpty) {
        _busy = false;
      } else {
        _waiting.removeFirst().complete();
      }
    }
  }

  static const String _failedAttemptsKey = 'pin_lockout_failed_attempts';
  static const String _lockedUntilKey = 'pin_lockout_until_ms';
  // The same deadline on elapsedRealtime, and the boot it belongs to (Y-05).
  static const String _lockedUntilElapsedKey = 'pin_lockout_until_elapsed_ms';
  static const String _lockedBootKey = 'pin_lockout_boot_count';
  static const String _lockedBootIdKey = 'pin_lockout_boot_id';
  // The length of the lockout those deadlines end: the attempt count that
  // implies it is written last and may be stale after a cut-short write.
  static const String _lockedDurationKey = 'pin_lockout_duration_ms';
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
  Future<PinLockoutRead> readState() => _serialized(_readState);

  Future<PinLockoutRead> _readState() async {
    final failedRaw = await _secureStorage.read(key: _failedAttemptsKey);
    final lockedUntilRaw = await _secureStorage.read(key: _lockedUntilKey);
    final failedAttempts = int.tryParse(failedRaw ?? '') ?? 0;
    final lockedUntilMs = int.tryParse(lockedUntilRaw ?? '');
    if ((failedRaw != null && (int.tryParse(failedRaw) == null || failedAttempts < 0)) ||
        (lockedUntilRaw != null && lockedUntilMs == null)) {
      return const PinLockoutUnreadable();
    }
    // An elapsed deadline without its wall key is a lockout write cut short
    // (elapsed keys are written first): still a lockout, never "none".
    final cutShort =
        lockedUntilMs == null &&
        await _secureStorage.read(key: _lockedUntilElapsedKey) != null;
    if (lockedUntilMs == null && !cutShort) {
      return PinLockoutReadable(
        PinLockoutState(failedAttempts: failedAttempts, lockedUntil: null),
      );
    }
    final (:remaining, :proven) = await _remaining(
      lockedUntilMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lockedUntilMs),
      failedAttempts,
    );
    if (proven && remaining <= Duration.zero) {
      // Ran out where it was measured: forget it, so a LATER reboot has
      // nothing to restart. The attempt count stays. An expiry nothing proved
      // keeps the keys for the next read that can prove it.
      await _secureStorage.delete(key: _lockedUntilKey);
      await _clearMonotonicDeadline();
    }
    return PinLockoutReadable(
      PinLockoutState(
        failedAttempts: failedAttempts,
        lockedUntil: remaining > Duration.zero
            ? DateTime.now().add(remaining)
            : null,
      ),
    );
  }

  /// Time left on a lockout (audit Y-05; reboot policy: owner decision
  /// 2026-10-09).
  ///
  /// The wall deadline alone let a user-set clock end a lockout at once
  /// (+1 h: an 86 s lockout gone) or stretch it (-2 h: 7431 s). Within the
  /// boot that set it, elapsedRealtime -- which nobody can set -- decides.
  /// Across a reboot the wall deadline used to decide, so reboot + clock
  /// forward ended any lockout for the price of one restart: a lockout found
  /// in a NEW boot now restarts for its full [duration] and is tied to that
  /// boot. Only without any monotonic reading does the wall deadline count,
  /// never for longer than the longest lockout the policy can impose.
  ///
  /// [proven] is false where the answer rests on nothing the user cannot set:
  /// a deadline stored on elapsedRealtime whose read failed now (a 500 ms
  /// channel timeout) stays locked, at least [_unprovenLock], until a read
  /// succeeds -- only on a platform with no bridge at all does the wall
  /// decide. Clock forward plus one failed read used to end and FORGET it.
  Future<({Duration remaining, bool proven})> _remaining(
    DateTime? wallUntil,
    int failedAttempts,
  ) async {
    final elapsedUntil = int.tryParse(
      await _secureStorage.read(key: _lockedUntilElapsedKey) ?? '',
    );
    final boot =
        int.tryParse(await _secureStorage.read(key: _lockedBootKey) ?? '') ??
        _unknownBoot;
    final bootId = await _secureStorage.read(key: _lockedBootIdKey);
    final storedMs = int.tryParse(
      await _secureStorage.read(key: _lockedDurationKey) ?? '',
    );
    final duration = _capped(
      storedMs != null && storedMs > 0
          ? Duration(milliseconds: storedMs)
          : Duration(seconds: lockoutSecondsFor(failedAttempts)),
    );
    final reading = elapsedUntil == null ? null : await _readMonotonic();
    if (reading == null) {
      final left = _capped((wallUntil ?? _now()).difference(_now()));
      if (elapsedUntil != null && _monotonicRequired()) {
        return (
          remaining: left < _unprovenLock ? _unprovenLock : left,
          proven: false,
        );
      }
      return (remaining: left, proven: elapsedUntil == null);
    }
    if (_fromAnotherBoot(reading, boot, bootId, elapsedUntil! - duration.inMilliseconds)) {
      await _anchor(reading, duration);
      return (remaining: duration, proven: true);
    }
    return (
      remaining: _capped(
        Duration(milliseconds: elapsedUntil - reading.elapsedMs),
      ),
      proven: true,
    );
  }

  static const Duration _unprovenLock = Duration(seconds: 1);

  static Duration _capped(Duration value) {
    const cap = Duration(seconds: maxLockoutSeconds);
    return value > cap ? cap : value;
  }

  /// Whether [reading] provably belongs to a later boot than the stored
  /// deadline: a different kernel boot id, else a different BOOT_COUNT, else
  /// an elapsed clock below the one at lock time ([stampMs]) -- it never runs
  /// backwards within a boot. With nothing to tell, the same boot.
  static bool _fromAnotherBoot(
    MonotonicReading reading,
    int boot,
    String? bootId,
    int stampMs,
  ) {
    final id = reading.bootId;
    if (id != null && bootId != null) return id != bootId;
    if (reading.bootCount != _unknownBoot && boot != _unknownBoot) {
      return reading.bootCount != boot;
    }
    return reading.elapsedMs < stampMs;
  }

  /// Ties a lockout of [length] to [reading]'s boot, starting now. Elapsed
  /// keys first, wall key last (see [registerFailure]).
  Future<void> _anchor(MonotonicReading reading, Duration length) async {
    await _secureStorage.write(
      key: _lockedDurationKey,
      value: '${length.inMilliseconds}',
    );
    await _secureStorage.write(
      key: _lockedUntilElapsedKey,
      value: '${reading.elapsedMs + length.inMilliseconds}',
    );
    await _secureStorage.write(key: _lockedBootKey, value: '${reading.bootCount}');
    final bootId = reading.bootId;
    await (bootId == null
        ? _secureStorage.delete(key: _lockedBootIdKey)
        : _secureStorage.write(key: _lockedBootIdKey, value: bootId));
    await _secureStorage.write(
      key: _lockedUntilKey,
      value: '${_now().add(length).millisecondsSinceEpoch}',
    );
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
  Future<PinLockoutState> registerFailure() => _serialized(_registerFailure);

  Future<PinLockoutState> _registerFailure() async {
    final read = await _readState();
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
      // The elapsed keys go FIRST. Written after the wall deadline, a process
      // killed in between left this fresh wall deadline beside an earlier,
      // expired elapsed one from the same boot, and that one decided: unlocked.
      // This way round an interrupted write leaves the newer elapsed deadline
      // (locked) or none at all (the wall deadline decides).
      final bootId = reading?.bootId;
      // Stored even with no boot identity: the elapsed clock at lock time
      // still tells a reboot (it restarts near zero) for most of a boot.
      if (reading != null) {
        await _secureStorage.write(
          key: _lockedDurationKey,
          value: '${seconds * 1000}',
        );
        await _secureStorage.write(
          key: _lockedUntilElapsedKey,
          value: '${reading.elapsedMs + seconds * 1000}',
        );
        await _secureStorage.write(
          key: _lockedBootKey,
          value: '${reading.bootCount}',
        );
        await (bootId == null
            ? _secureStorage.delete(key: _lockedBootIdKey)
            : _secureStorage.write(key: _lockedBootIdKey, value: bootId));
      } else {
        await _clearMonotonicDeadline();
      }
      await _secureStorage.write(
        key: _lockedUntilKey,
        value: '${lockedUntil.millisecondsSinceEpoch}',
      );
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

  Future<void> reset() => _serialized(_reset);

  Future<void> _reset() async {
    await Future.wait([
      _secureStorage.delete(key: _failedAttemptsKey),
      _secureStorage.delete(key: _lockedUntilKey),
      _secureStorage.delete(key: _lockedUntilElapsedKey),
      _secureStorage.delete(key: _lockedBootKey),
      _secureStorage.delete(key: _lockedBootIdKey),
      _secureStorage.delete(key: _lockedDurationKey),
    ]);
  }

  Future<void> _clearMonotonicDeadline() async {
    await _secureStorage.delete(key: _lockedUntilElapsedKey);
    await _secureStorage.delete(key: _lockedBootKey);
    await _secureStorage.delete(key: _lockedBootIdKey);
    await _secureStorage.delete(key: _lockedDurationKey);
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
