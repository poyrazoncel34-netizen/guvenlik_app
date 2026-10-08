// Y-12 (chaos audit 2026-10-08, review of the Y-04/Y-01 fix): the monotonic
// clock behind every Dart safety projection was a plain Stopwatch. On Android
// that is CLOCK_MONOTONIC, which STOPS while the device sleeps, whereas the
// native alarms run on elapsedRealtime (CLOCK_BOOTTIME), which keeps counting.
// A panic countdown whose screen went off at T+3 still showed ~7 s and a live
// PIN pad after native had called; with no native session (dialer fallback) the
// dialer opened only after the un-slept remainder had run out.

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/safety_clock.dart';

class _Clock implements SafetyClock {
  _Clock(this.source);

  final SleepCountingMonotonic source;

  @override
  DateTime now() => DateTime(2026, 10, 8, 19);

  @override
  Duration get monotonic => source.elapsed;
}

void main() {
  test('time the device spends asleep counts toward a deadline', () {
    var bootUs = 1000000000;
    var awake = Duration.zero;
    final clock = _Clock(
      SleepCountingMonotonic(() => bootUs, fallback: () => awake),
    );
    final deadline = MonotonicDeadline(clock, const Duration(seconds: 10));

    bootUs += 3000000;
    awake += const Duration(seconds: 3);
    expect(deadline.secondsLeft, 7);

    // Screen off, CPU suspended for 30 s: only the boot clock moves.
    bootUs += 30000000;
    expect(deadline.isDue, isTrue);
  });

  test('without a boot clock the fallback is the clock', () {
    var awake = const Duration(seconds: 4);
    final source = SleepCountingMonotonic(null, fallback: () => awake);
    final first = source.elapsed;
    awake += const Duration(seconds: 2);
    expect(source.elapsed - first, const Duration(seconds: 2));
  });

  test(
    'a failed boot read continues from the last reading, never backwards',
    () {
      int? bootUs = 5000000;
      var awake = const Duration(seconds: 1);
      final source = SleepCountingMonotonic(
        () => bootUs,
        fallback: () => awake,
      );
      expect(source.elapsed, const Duration(seconds: 5));

      bootUs = null;
      awake = const Duration(seconds: 3);
      expect(source.elapsed, const Duration(seconds: 7));

      // Recovered: the boot clock advanced at least as far as the fallback.
      bootUs = 9000000;
      awake = const Duration(seconds: 4);
      expect(source.elapsed, const Duration(seconds: 9));
    },
  );

  test('a boot clock that fails its first read is never adopted later', () {
    int? bootUs;
    var awake = Duration.zero;
    final source = SleepCountingMonotonic(() => bootUs, fallback: () => awake);
    final first = source.elapsed;

    // Switching sources mid-countdown would jump hours ahead and expire every
    // deadline at once.
    bootUs = 7200000000;
    awake += const Duration(seconds: 1);
    expect(source.elapsed - first, const Duration(seconds: 1));
  });
}
