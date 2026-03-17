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
      final state = await service.getState();
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
      final s4 = await service.getState();
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
      final s5 = await service.getState();
      expect(s5.remainingSeconds, inInclusiveRange(28, 31));

      await service.reset();
      _fakeStorage.clear();
      for (var i = 0; i < 6; i++) {
        await service.registerFailure();
      }
      final s6 = await service.getState();
      expect(s6.remainingSeconds, inInclusiveRange(58, 61));
    });

    test('reset clears all lockout data', () async {
      for (var i = 0; i < 5; i++) {
        await service.registerFailure();
      }
      final locked = await service.getState();
      expect(locked.isLocked, isTrue);

      await service.reset();
      final cleared = await service.getState();
      expect(cleared.failedAttempts, 0);
      expect(cleared.isLocked, isFalse);
    });

    test('getState clears expired lock', () async {
      await _fakeStorage.write(
        key: 'pin_lockout_failed_attempts',
        value: '5',
      );
      await _fakeStorage.write(
        key: 'pin_lockout_until_ms',
        value: '${DateTime.now().subtract(const Duration(seconds: 10)).millisecondsSinceEpoch}',
      );
      final state = await service.getState();
      expect(state.failedAttempts, 5);
      expect(state.isLocked, isFalse);
      expect(state.lockedUntil, isNull);
    });
  });
}
