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
  PinLockoutService._({SecureStorage? secureStorage})
    : _injectedStorage = secureStorage;

  factory PinLockoutService.forTesting({required SecureStorage secureStorage}) {
    return PinLockoutService._(secureStorage: secureStorage);
  }

  static final PinLockoutService instance = PinLockoutService._();

  static const String _failedAttemptsKey = 'pin_lockout_failed_attempts';
  static const String _lockedUntilKey = 'pin_lockout_until_ms';

  final SecureStorage? _injectedStorage;

  SecureStorage get _secureStorage =>
      _injectedStorage ?? serviceLocator<SecureStorage>();

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
      final exponent = failedAttempts - 5;
      final seconds = 30 * pow(2, exponent).toInt();
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
