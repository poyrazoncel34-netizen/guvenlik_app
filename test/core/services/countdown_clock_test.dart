import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/countdown_clock.dart';

void main() {
  final now = DateTime(2026, 7, 25, 12, 0, 0);

  test('a full ten-second window reads as ten', () {
    expect(
      CountdownClock.secondsUntil(
        now.add(const Duration(seconds: 10)),
        now: now,
      ),
      10,
    );
  });

  test('a partial second still counts as that second, never as fewer', () {
    expect(
      CountdownClock.secondsUntil(
        now.add(const Duration(milliseconds: 4200)),
        now: now,
      ),
      5,
      reason:
          'Rounding down would show a second the user no longer has, and the '
          'visible cancel window must never be shorter than it looks.',
    );
    expect(
      CountdownClock.secondsUntil(
        now.add(const Duration(milliseconds: 1)),
        now: now,
      ),
      1,
    );
  });

  test('the deadline and anything past it clamp to zero', () {
    for (final offset in <Duration>[
      Duration.zero,
      const Duration(milliseconds: -1),
      const Duration(seconds: -30),
    ]) {
      expect(CountdownClock.secondsUntil(now.add(offset), now: now), 0);
    }
  });

  test('arm latency shortens the display instead of outliving the alarm', () {
    // The session is armed with an absolute deadline BEFORE the channel round
    // trip; a slow arm used to leave the UI counting from ten afterwards.
    final deadline = now.add(const Duration(seconds: 10));
    final afterSlowArm = now.add(const Duration(milliseconds: 1500));

    expect(CountdownClock.secondsUntil(deadline, now: afterSlowArm), 9);
    expect(
      CountdownClock.secondsUntil(
        deadline,
        now: now.add(const Duration(seconds: 10)),
      ),
      0,
      reason: 'UI reaches zero exactly when the native alarm is due.',
    );
  });

  // Native gates dispatch on `System.currentTimeMillis() < finalDeadlineMs`,
  // a millisecond floor of the same wall clock Dart reads, and its deadline is
  // the Dart deadline truncated to milliseconds. Zero here means "dispatch
  // now", so zero must never be reported while that gate would still refuse:
  // the panic path treats a refusal as unknown and opens the dialer, and the
  // native alarm then places the automatic request as well.
  bool nativeWouldAccept(DateTime deadline, DateTime now) =>
      now.millisecondsSinceEpoch >= deadline.millisecondsSinceEpoch;

  test('zero is never reported inside the last millisecond before the deadline', () {
    final deadline = now.add(const Duration(seconds: 10, microseconds: 437));
    for (final us in <int>[1, 10, 100, 499, 500, 999]) {
      final at = deadline.subtract(Duration(microseconds: us));
      expect(
        CountdownClock.secondsUntil(deadline, now: at),
        1,
        reason: '${us}us before the deadline is not the deadline',
      );
    }
  });

  test('randomized: a zero reading always passes the native millisecond gate', () {
    final random = Random(20261006);
    for (var i = 0; i < 20000; i++) {
      final deadline = now.add(
        Duration(microseconds: 10 * 1000000 + random.nextInt(1000000)),
      );
      final at = deadline.add(Duration(microseconds: random.nextInt(4000) - 2000));
      if (CountdownClock.secondsUntil(deadline, now: at) == 0) {
        expect(nativeWouldAccept(deadline, at), isTrue, reason: '$deadline @ $at');
        expect(at.isBefore(deadline), isFalse, reason: '$deadline @ $at');
      }
    }
  });

  test('randomized ticker: never fires early, and is late by less than one period', () {
    final random = Random(42);
    const offsetsMs = <int>[1, 10, 100, 499, 500, 999, 1000, 1001, 2000, 9999];
    for (final period in const <Duration>[
      Duration(milliseconds: 200), // panic countdown poll
      Duration(seconds: 1), // check-in / safe walk ticker
    ]) {
      var worstLateUs = 0;
      for (var i = 0; i < 4000; i++) {
        final offsetUs = i < offsetsMs.length * 10
            ? offsetsMs[i % offsetsMs.length] * 1000 + random.nextInt(1000)
            : random.nextInt(30 * 1000000) + 1;
        final deadline = now.add(Duration(microseconds: offsetUs));
        var tick = now.add(Duration(microseconds: random.nextInt(period.inMicroseconds)));
        while (CountdownClock.secondsUntil(deadline, now: tick) > 0) {
          tick = tick.add(period);
        }
        expect(tick.isBefore(deadline), isFalse, reason: 'early: $deadline @ $tick');
        expect(nativeWouldAccept(deadline, tick), isTrue);
        final lateUs = tick.difference(deadline).inMicroseconds;
        expect(lateUs, lessThan(period.inMicroseconds));
        worstLateUs = max(worstLateUs, lateUs);
      }
      // Measured, not assumed: the Dart mirror trails the native alarm by at
      // most one polling period. The native alarm itself is not delayed.
      expect(worstLateUs, greaterThan(0));
    }
  });
}
