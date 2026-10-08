// Y-01 / Y-04 (chaos audit 2026-10-08): a safety timer is a DURATION. Native
// keeps it one (ELAPSED_REALTIME alarms, TIME_SET rebasing), but every Dart
// projection divided an absolute wall-clock deadline by DateTime.now(). On an
// API 35 emulator a +1 h clock change during a panic countdown opened the
// dialer at once (and the native call still followed at the real deadline); a
// -2 h change made Check-In show "134:19" with fourteen minutes left.

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/safety_clock.dart';

class _FakeClock implements SafetyClock {
  DateTime wall = DateTime(2026, 10, 8, 14, 20);
  Duration elapsed = Duration.zero;

  @override
  DateTime now() => wall;

  @override
  Duration get monotonic => elapsed;
}

void main() {
  test('a wall-clock jump in either direction does not move the deadline', () {
    final clock = _FakeClock();
    final deadline = MonotonicDeadline(clock, const Duration(seconds: 10));

    clock.elapsed += const Duration(seconds: 1);
    clock.wall = clock.wall.add(const Duration(hours: 1));
    expect(deadline.secondsLeft, 9);

    clock.wall = clock.wall.subtract(const Duration(hours: 3));
    expect(deadline.secondsLeft, 9);
    expect(deadline.isDue, isFalse);
  });

  test('zero is reported only once the full duration has elapsed', () {
    final clock = _FakeClock();
    final deadline = MonotonicDeadline(clock, const Duration(seconds: 10));

    clock.elapsed =
        const Duration(seconds: 10) - const Duration(microseconds: 1);
    expect(deadline.secondsLeft, 1, reason: 'rounded UP, never early');
    expect(deadline.isDue, isFalse);

    clock.elapsed = const Duration(seconds: 10);
    expect(deadline.secondsLeft, 0);
    expect(deadline.isDue, isTrue);

    clock.elapsed = const Duration(seconds: 25);
    expect(deadline.secondsLeft, 0, reason: 'clamped at zero');
  });

  test('fromWall is anchored at the moment it was built', () {
    final clock = _FakeClock();
    clock.elapsed = const Duration(minutes: 3);
    final deadline = MonotonicDeadline.fromWall(
      clock,
      clock.wall.add(const Duration(minutes: 15)),
    );
    expect(deadline.secondsLeft, 15 * 60);

    clock.elapsed += const Duration(minutes: 14);
    clock.wall = clock.wall.subtract(const Duration(hours: 2));
    expect(deadline.secondsLeft, 60);
  });

  test('a wall deadline already in the past is due at once', () {
    final clock = _FakeClock();
    final deadline = MonotonicDeadline.fromWall(
      clock,
      clock.wall.subtract(const Duration(seconds: 5)),
    );
    expect(deadline.isDue, isTrue);
    expect(deadline.secondsLeft, 0);
  });

  test('the system clock is monotonic and starts near zero cost', () {
    final first = SafetyClock.system.monotonic;
    final second = SafetyClock.system.monotonic;
    expect(second >= first, isTrue);
  });
}
