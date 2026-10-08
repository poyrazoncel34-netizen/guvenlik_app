// Y-05 (chaos audit 2026-10-08): the PIN lockout stored only a wall-clock
// deadline. On an API 35 emulator an 86 s lockout ended at once when the clock
// was moved forward an hour (a brute-force bypass for whoever holds the
// phone), and moving it back two hours locked the owner out for 7431 s.
// Within one boot the lockout now runs on elapsedRealtime; across boots, or
// without it, the wall deadline still counts but can never exceed the longest
// lockout the policy can impose.

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/pin_lockout_service.dart';

class _Storage extends SecureStorage {
  final Map<String, String> values = <String, String>{};
  @override
  Future<String?> read({required String key}) async => values[key];
  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;
  @override
  Future<void> delete({required String key}) async => values.remove(key);
  @override
  Future<void> deleteAll() async => values.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late DateTime wall;
  late MonotonicReading? reading;
  late PinLockoutService service;

  setUp(() async {
    await serviceLocator.reset();
    storage = _Storage();
    serviceLocator.registerSingleton<SecureStorage>(storage);
    wall = DateTime.now();
    reading = (elapsedMs: 1000000, bootCount: 17);
    service = PinLockoutService.forTesting(
      monotonic: () async => reading,
      now: () => wall,
    );
  });

  tearDown(serviceLocator.reset);

  Future<PinLockoutState> lockFor30Seconds() async {
    storage.values['pin_lockout_failed_attempts'] = '4';
    final state = await service.registerFailure();
    expect(state.isLocked, isTrue);
    return state;
  }

  Future<PinLockoutState> read() async =>
      (await service.readState() as PinLockoutReadable).state;

  void advance(Duration by, {Duration wallJump = Duration.zero}) {
    final current = reading!;
    reading = (
      elapsedMs: current.elapsedMs + by.inMilliseconds,
      bootCount: current.bootCount,
    );
    wall = wall.add(by).add(wallJump);
  }

  test('moving the clock forward does not end the lockout', () async {
    await lockFor30Seconds();
    advance(const Duration(seconds: 1), wallJump: const Duration(hours: 1));

    final state = await read();
    expect(state.isLocked, isTrue);
    expect(state.remainingSeconds, inInclusiveRange(27, 29));
  });

  test('moving the clock back does not stretch the lockout', () async {
    await lockFor30Seconds();
    advance(const Duration(seconds: 1), wallJump: const Duration(hours: -2));

    final state = await read();
    expect(state.isLocked, isTrue);
    expect(state.remainingSeconds, inInclusiveRange(27, 29));
  });

  test('the lockout ends when its duration has elapsed, not before', () async {
    await lockFor30Seconds();
    advance(const Duration(seconds: 29));
    expect((await read()).isLocked, isTrue);

    advance(const Duration(seconds: 2));
    final state = await read();
    expect(state.isLocked, isFalse);
    expect(state.lockedUntil, isNull);
    expect(state.failedAttempts, 5, reason: 'the count itself is kept');
  });

  test('after a reboot the wall deadline counts again', () async {
    await lockFor30Seconds();
    reading = (elapsedMs: 15000, bootCount: 18);
    wall = wall.add(const Duration(seconds: 5));

    final state = await read();
    expect(state.isLocked, isTrue);
    expect(state.remainingSeconds, inInclusiveRange(23, 25));
  });

  test('a clock moved back across a reboot cannot lock the owner out for '
      'longer than the policy maximum', () async {
    await lockFor30Seconds();
    reading = (elapsedMs: 15000, bootCount: 18);
    wall = wall.subtract(const Duration(hours: 2));

    final state = await read();
    expect(state.isLocked, isTrue);
    expect(
      state.remainingSeconds,
      lessThanOrEqualTo(PinLockoutService.maxLockoutSeconds),
    );
  });

  test(
    'without a monotonic reading the wall deadline counts, capped',
    () async {
      reading = null;
      await lockFor30Seconds();
      wall = wall.subtract(const Duration(hours: 2));

      final state = await read();
      expect(
        state.remainingSeconds,
        lessThanOrEqualTo(PinLockoutService.maxLockoutSeconds),
      );
      expect(state.isLocked, isTrue);
    },
  );

  test('reset forgets every lockout key', () async {
    await lockFor30Seconds();
    await service.reset();
    expect(
      storage.values.keys.where((k) => k.startsWith('pin_lockout')),
      isEmpty,
    );
  });
}
