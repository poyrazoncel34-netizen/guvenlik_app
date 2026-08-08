// The app's springs sit on safety controls, so "no overshoot" is a behavioural
// guarantee, not a taste preference: a panic control that springs past its
// target and bounces back reads as playful at the exact moment it must not.
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/motion.dart';

void main() {
  group('Motion.settle', () {
    test('never overshoots the target it is released toward', () {
      const start = 0.7;
      final simulation = SpringSimulation(Motion.settle, start, 0, 0);

      for (var ms = 0; ms <= 2000; ms += 10) {
        final value = simulation.x(ms / 1000);
        expect(
          value,
          inInclusiveRange(-1e-6, start + 1e-6),
          reason: 'overshoot at ${ms}ms: $value',
        );
      }
    });

    test('decays monotonically — no wobble on the way home', () {
      final simulation = SpringSimulation(Motion.settle, 1, 0, 0);
      var previous = simulation.x(0);

      for (var ms = 10; ms <= 2000; ms += 10) {
        final value = simulation.x(ms / 1000);
        expect(
          value,
          lessThanOrEqualTo(previous + 1e-9),
          reason: 'value rose at ${ms}ms: $previous -> $value',
        );
        previous = value;
      }
    });

    test('settles within roughly half a second, not seconds', () {
      final simulation = SpringSimulation(Motion.settle, 1, 0, 0);

      expect(
        simulation.isDone(0.15),
        isFalse,
        reason: 'an instant snap would be the hard cut this replaces',
      );
      expect(
        simulation.isDone(0.9),
        isTrue,
        reason: 'a released control must not still be drifting a second later',
      );
    });

    test('a released gesture keeps its direction when handed a velocity', () {
      // Negative velocity = still travelling toward the target on release.
      final simulation = SpringSimulation(Motion.settle, 0.5, 0, -1.0);

      expect(simulation.x(0.02), lessThan(0.5));
    });
  });
}
