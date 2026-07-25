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

class PinLockoutService {
  PinLockoutService._();

  static final PinLockoutService instance = PinLockoutService._();

  static const String _failedAttemptsKey = 'pin_lockout_failed_attempts';
  static const String _lockedUntilKey = 'pin_lockout_until_ms';

  /// First lockout length, applied at the 5th consecutive failure.
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
    if (failedAttempts < 5) return 0;
    final exponent = failedAttempts - 5;
    // Stop doubling before the value can leave the int range; the cap applies
    // long before this bound, so the clamp is a safety net, not the policy.
    if (exponent >= 32) return maxLockoutSeconds;
    final seconds = baseLockoutSeconds * pow(2, exponent).toInt();
    return seconds > maxLockoutSeconds ? maxLockoutSeconds : seconds;
  }

  final SecureStorage _secureStorage = serviceLocator<SecureStorage>();

  Future<PinLockoutState> getState() async {
    final failedRaw = await _secureStorage.read(key: _failedAttemptsKey);
    final lockedUntilRaw = await _secureStorage.read(key: _lockedUntilKey);
    final failedAttempts = int.tryParse(failedRaw ?? '') ?? 0;
    final lockedUntilMs = int.tryParse(lockedUntilRaw ?? '');
    final lockedUntil = lockedUntilMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lockedUntilMs);

    if (lockedUntil != null && DateTime.now().isAfter(lockedUntil)) {
      return PinLockoutState(failedAttempts: failedAttempts, lockedUntil: null);
    }

    return PinLockoutState(
      failedAttempts: failedAttempts,
      lockedUntil: lockedUntil,
    );
  }

  Future<PinLockoutState> registerFailure() async {
    final current = await getState();
    final failedAttempts = current.failedAttempts + 1;

    DateTime? lockedUntil;
    if (failedAttempts >= 5) {
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

  Stream<int> countdownStream(PinLockoutState initial) async* {
    var state = initial;
    while (state.isLocked) {
      yield state.remainingSeconds;
      await Future<void>.delayed(const Duration(seconds: 1));
      state = await getState();
    }
    yield 0;
  }
}
