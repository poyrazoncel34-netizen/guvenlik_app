import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/pin_lockout_service.dart';

void main() {
  test('no lockout before the fifth consecutive failure', () {
    for (var attempts = 0; attempts < 5; attempts++) {
      expect(PinLockoutService.lockoutSecondsFor(attempts), 0);
    }
  });

  test('backoff doubles from 30 seconds', () {
    expect(PinLockoutService.lockoutSecondsFor(5), 30);
    expect(PinLockoutService.lockoutSecondsFor(6), 60);
    expect(PinLockoutService.lockoutSecondsFor(7), 120);
    expect(PinLockoutService.lockoutSecondsFor(8), 240);
  });

  test('backoff never exceeds the cap, however many failures accumulate', () {
    for (final attempts in <int>[15, 18, 20, 25, 44, 69, 200, 100000]) {
      final seconds = PinLockoutService.lockoutSecondsFor(attempts);
      expect(
        seconds,
        inInclusiveRange(1, PinLockoutService.maxLockoutSeconds),
        reason:
            'Uncapped doubling locked the owner out for days at 20 failures '
            'and overflowed into no lockout at all past ~44.',
      );
    }
  });

  test('the cap is reached and then held, never reset to a shorter window', () {
    final atCap = PinLockoutService.lockoutSecondsFor(16);
    expect(atCap, PinLockoutService.maxLockoutSeconds);
    var previous = 0;
    for (var attempts = 5; attempts <= 80; attempts++) {
      final seconds = PinLockoutService.lockoutSecondsFor(attempts);
      expect(seconds, greaterThanOrEqualTo(previous));
      previous = seconds;
    }
    expect(previous, PinLockoutService.maxLockoutSeconds);
  });
}
