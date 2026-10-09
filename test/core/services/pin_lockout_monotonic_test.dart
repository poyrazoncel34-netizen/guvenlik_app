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

  /// A write to this key throws once: the process died mid-lockout-write.
  String? failWriteOf;
  @override
  Future<String?> read({required String key}) async => values[key];
  @override
  Future<void> write({required String key, required String value}) async {
    if (key == failWriteOf) {
      failWriteOf = null;
      throw Exception('process died');
    }
    values[key] = value;
  }

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
    reading = (elapsedMs: 1000000, bootCount: 17, bootId: null);
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
      bootId: current.bootId,
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

  // Owner decision 2026-10-09: rebooting must not reset the lockout. Across a
  // reboot the wall deadline used to decide, so reboot + clock forward ended
  // any lockout for the price of one restart. Now a lockout found active in a
  // new boot restarts for its full duration, tied to the new boot.
  test(
    'a reboot restarts an active lockout instead of trusting the wall',
    () async {
      await lockFor30Seconds();
      reading = (elapsedMs: 15000, bootCount: 18, bootId: null);
      wall = wall.add(const Duration(days: 1));

      final state = await read();
      expect(state.isLocked, isTrue);
      expect(state.remainingSeconds, inInclusiveRange(28, 30));
    },
  );

  test('after the restart the new boot runs it monotonically: +1 day, -1 day '
      'and a process kill change nothing', () async {
    await lockFor30Seconds();
    reading = (elapsedMs: 15000, bootCount: 18, bootId: null);
    await read();

    advance(const Duration(seconds: 10), wallJump: const Duration(days: 1));
    expect((await read()).remainingSeconds, inInclusiveRange(18, 20));
    advance(const Duration(seconds: 1), wallJump: const Duration(days: -2));
    expect((await read()).remainingSeconds, inInclusiveRange(17, 19));

    // A fresh service instance is a process restart.
    service = PinLockoutService.forTesting(
      monotonic: () async => reading,
      now: () => wall,
    );
    expect((await read()).isLocked, isTrue);
    advance(const Duration(seconds: 20));
    expect((await read()).isLocked, isFalse);
  });

  test('two reboots in a row keep it locked', () async {
    await lockFor30Seconds();
    reading = (elapsedMs: 15000, bootCount: 18, bootId: null);
    await read();
    reading = (elapsedMs: 9000, bootCount: 19, bootId: null);
    wall = wall.add(const Duration(hours: 5));

    final state = await read();
    expect(state.isLocked, isTrue);
    expect(state.remainingSeconds, inInclusiveRange(28, 30));
  });

  test('a lockout that ran out in its own boot is forgotten, so a later '
      'reboot does not restart it', () async {
    await lockFor30Seconds();
    advance(const Duration(seconds: 31));
    expect((await read()).isLocked, isFalse);

    reading = (elapsedMs: 15000, bootCount: 18, bootId: null);
    final state = await read();
    expect(state.isLocked, isFalse);
    expect(state.failedAttempts, 5, reason: 'the attempt count is kept');
  });

  test('with no boot identity on either side an elapsed clock below the lock '
      'stamp is a reboot; above it, the same boot', () async {
    reading = (elapsedMs: 1000000, bootCount: -1, bootId: null);
    await lockFor30Seconds();

    advance(const Duration(seconds: 5), wallJump: const Duration(days: 1));
    expect((await read()).remainingSeconds, inInclusiveRange(24, 25));

    reading = (elapsedMs: 4000, bootCount: -1, bootId: null);
    final state = await read();
    expect(state.isLocked, isTrue);
    expect(state.remainingSeconds, inInclusiveRange(28, 30));
  });

  test('a clock moved back across a reboot cannot lock the owner out for '
      'longer than the policy maximum', () async {
    await lockFor30Seconds();
    reading = (elapsedMs: 15000, bootCount: 18, bootId: null);
    wall = wall.subtract(const Duration(hours: 2));

    final state = await read();
    expect(state.isLocked, isTrue);
    expect(
      state.remainingSeconds,
      lessThanOrEqualTo(PinLockoutService.maxLockoutSeconds),
    );
    expect(state.remainingSeconds, inInclusiveRange(28, 30));
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

  // Review of Y-05: the snapshot carried only BOOT_COUNT, so a device that
  // cannot read it fell back to the settable wall clock entirely. The kernel
  // boot id decides there, as it does natively (A-02r).
  test('with BOOT_COUNT unreadable the kernel boot id keeps the lockout '
      'monotonic', () async {
    reading = (elapsedMs: 1000000, bootCount: -1, bootId: 'boot-a');
    await lockFor30Seconds();
    advance(const Duration(seconds: 1), wallJump: const Duration(hours: 1));

    final state = await read();
    expect(state.isLocked, isTrue);
    expect(state.remainingSeconds, inInclusiveRange(27, 29));
  });

  test(
    'a new kernel boot id is a new boot even with an equal BOOT_COUNT',
    () async {
      reading = (elapsedMs: 1000000, bootCount: 17, bootId: 'boot-a');
      await lockFor30Seconds();
      // Rebooted; uptime happens to be past the old deadline.
      reading = (elapsedMs: 2000000, bootCount: 17, bootId: 'boot-b');
      wall = wall.add(const Duration(seconds: 5));

      final state = await read();
      expect(state.isLocked, isTrue, reason: 'a new boot restarts it');
      expect(state.remainingSeconds, inInclusiveRange(28, 30));
    },
  );

  // Review of Y-05: the wall deadline was written before the elapsed keys. A
  // process killed between the two left a FRESH wall deadline next to the
  // EXPIRED elapsed deadline of an earlier lockout in the same boot, and the
  // expired one decided: unlocked.
  test(
    'a lockout write cut short never leaves an expired deadline in charge',
    () async {
      await lockFor30Seconds();
      advance(const Duration(seconds: 31));
      expect((await read()).isLocked, isFalse);

      storage.failWriteOf = 'pin_lockout_until_ms';
      await expectLater(service.registerFailure(), throwsException);
      storage.values['pin_lockout_failed_attempts'] = '5';
      storage.failWriteOf = 'pin_lockout_until_elapsed_ms';
      await expectLater(service.registerFailure(), throwsException);

      // Whatever got written, an expired elapsed deadline must not decide.
      final stored = storage.values['pin_lockout_until_elapsed_ms'];
      if (stored != null) {
        expect(
          int.parse(stored),
          greaterThan(reading!.elapsedMs),
          reason: 'a stored elapsed deadline must belong to the newest lockout',
        );
      }
      expect((await read()).isLocked, isTrue);
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
