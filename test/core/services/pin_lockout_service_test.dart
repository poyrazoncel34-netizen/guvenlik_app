import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:guvenlik_app/core/services/pin_lockout_service.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';

/// In-memory [SecureStorage] stub for testing.
class FakeSecureStorage extends SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> delete({required String key}) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();

  void clear() => _store.clear();
}

/// Because PinLockoutService is a singleton that captures SecureStorage at
/// instantiation time, we register the fake ONCE and just clear its data
/// between tests.
late FakeSecureStorage _fakeStorage;
bool _serviceLocatorReady = false;

/// Unwraps a read the test expects to be trustworthy.
///
/// Deliberately NOT a silent fallback: if the service ever starts returning
/// [PinLockoutUnreadable] for data these tests wrote, the test must fail rather
/// than quietly assert against an invented zero state.
Future<PinLockoutState> _readable(PinLockoutService service) async {
  final read = await service.readState();
  expect(
    read,
    isA<PinLockoutReadable>(),
    reason: 'the counters written by this test must read back as trustworthy',
  );
  return (read as PinLockoutReadable).state;
}

void main() {
  setUp(() {
    if (!_serviceLocatorReady) {
      _fakeStorage = FakeSecureStorage();
      GetIt.instance.registerSingleton<SecureStorage>(_fakeStorage);
      _serviceLocatorReady = true;
    }
    _fakeStorage.clear();
  });

  group('PinLockoutState', () {
    test('isLocked returns false when lockedUntil is null', () {
      const state = PinLockoutState(failedAttempts: 3, lockedUntil: null);
      expect(state.isLocked, isFalse);
      expect(state.remainingSeconds, 0);
    });

    test('isLocked returns true when lockedUntil is in the future', () {
      final future = DateTime.now().add(const Duration(seconds: 60));
      final state = PinLockoutState(failedAttempts: 5, lockedUntil: future);
      expect(state.isLocked, isTrue);
      expect(state.remainingSeconds, greaterThan(0));
    });

    test('isLocked returns false when lockedUntil is in the past', () {
      final past = DateTime.now().subtract(const Duration(seconds: 10));
      final state = PinLockoutState(failedAttempts: 5, lockedUntil: past);
      expect(state.isLocked, isFalse);
      expect(state.remainingSeconds, 0);
    });
  });

  group('PinLockoutService', () {
    late PinLockoutService service;

    setUp(() {
      service = PinLockoutService.instance;
    });

    test('getState returns zero attempts initially', () async {
      final state = await _readable(service);
      expect(state.failedAttempts, 0);
      expect(state.isLocked, isFalse);
    });

    test('registerFailure increments attempt count', () async {
      final s1 = await service.registerFailure();
      expect(s1.failedAttempts, 1);
      expect(s1.isLocked, isFalse);

      final s2 = await service.registerFailure();
      expect(s2.failedAttempts, 2);
      expect(s2.isLocked, isFalse);
    });

    test('lockout triggers at 5 failed attempts', () async {
      for (var i = 0; i < 4; i++) {
        await service.registerFailure();
      }
      final s4 = await _readable(service);
      expect(s4.failedAttempts, 4);
      expect(s4.isLocked, isFalse);

      final s5 = await service.registerFailure();
      expect(s5.failedAttempts, 5);
      expect(s5.isLocked, isTrue);
      expect(s5.lockedUntil, isNotNull);
    });

    test('exponential backoff: 5th=30s, 6th=60s', () async {
      for (var i = 0; i < 5; i++) {
        await service.registerFailure();
      }
      final s5 = await _readable(service);
      expect(s5.remainingSeconds, inInclusiveRange(28, 31));

      await service.reset();
      _fakeStorage.clear();
      for (var i = 0; i < 6; i++) {
        await service.registerFailure();
      }
      final s6 = await _readable(service);
      expect(s6.remainingSeconds, inInclusiveRange(58, 61));
    });

    test('reset clears all lockout data', () async {
      for (var i = 0; i < 5; i++) {
        await service.registerFailure();
      }
      final locked = await _readable(service);
      expect(locked.isLocked, isTrue);

      await service.reset();
      final cleared = await _readable(service);
      expect(cleared.failedAttempts, 0);
      expect(cleared.isLocked, isFalse);
    });

    // ------------------------------------------------------------------
    // Corrupt counters are a RESULT, not an exception.
    //
    // readState() used to `throw StateError`, which forced both call sites to
    // catch an Error subtype. Typing the outcome means the compiler now refuses
    // a caller that forgets the case, and the fail-closed behaviour no longer
    // depends on someone remembering a catch clause.
    // ------------------------------------------------------------------

    test('a non-numeric attempt total reads as unreadable, it does not throw',
        () async {
      await _fakeStorage.write(
        key: 'pin_lockout_failed_attempts',
        value: 'not-a-number',
      );

      expect(await service.readState(), isA<PinLockoutUnreadable>());
    });

    test('a negative attempt total reads as unreadable', () async {
      await _fakeStorage.write(
        key: 'pin_lockout_failed_attempts',
        value: '-3',
      );

      expect(await service.readState(), isA<PinLockoutUnreadable>());
    });

    test('an unparseable deadline reads as unreadable', () async {
      await _fakeStorage.write(key: 'pin_lockout_until_ms', value: 'soon');

      expect(await service.readState(), isA<PinLockoutUnreadable>());
    });

    test('an empty store is readable and clean, not unreadable', () async {
      // The negative control. If absence read as "unreadable", every first
      // launch would arrive pre-locked.
      final read = await service.readState();

      expect(read, isA<PinLockoutReadable>());
      expect((read as PinLockoutReadable).state.failedAttempts, 0);
      expect(read.state.isLocked, isFalse);
    });

    test('a failure on a corrupt counter locks immediately, it does not restart '
        'the count at zero', () async {
      await _fakeStorage.write(
        key: 'pin_lockout_failed_attempts',
        value: 'garbage',
      );

      final state = await service.registerFailure();

      // Debited from the threshold, not from zero: a corrupt counter must never
      // buy the attacker a fresh set of free guesses. Corrupting the store is
      // something an attacker holding the device can attempt.
      expect(state.failedAttempts, PinLockoutService.lockoutThreshold);
      expect(
        state.isLocked,
        isTrue,
        reason:
            'if this restarted at 1 the attacker would get four more free '
            'guesses for every corruption',
      );
    });

    test('countdownStream stops on an unreadable counter instead of guessing',
        () async {
      await _fakeStorage.write(key: 'pin_lockout_failed_attempts', value: '5');
      await _fakeStorage.write(
        key: 'pin_lockout_until_ms',
        value:
            '${DateTime.now().add(const Duration(seconds: 5)).millisecondsSinceEpoch}',
      );
      final initial = await _readable(service);

      // Corrupt the store mid-stream, the way a failing keystore would.
      final emitted = <int>[];
      final subscription = service.countdownStream(initial).listen(emitted.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await _fakeStorage.write(
        key: 'pin_lockout_until_ms',
        value: 'corrupted',
      );
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await subscription.cancel();

      expect(
        emitted,
        isNot(contains(0)),
        reason:
            'emitting 0 would clear the band on the screen; an unreadable '
            'counter is not evidence that the lockout expired',
      );
    });

    test('readState clears expired lock', () async {
      await _fakeStorage.write(key: 'pin_lockout_failed_attempts', value: '5');
      await _fakeStorage.write(
        key: 'pin_lockout_until_ms',
        value:
            '${DateTime.now().subtract(const Duration(seconds: 10)).millisecondsSinceEpoch}',
      );
      final state = await _readable(service);
      expect(state.failedAttempts, 5);
      expect(state.isLocked, isFalse);
      expect(state.lockedUntil, isNull);
    });
  });
}
