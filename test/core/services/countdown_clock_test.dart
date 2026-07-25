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
}
