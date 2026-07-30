import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/reduced_motion_policy.dart';

void main() {
  late TickerProvider ticker;

  setUp(() {
    ticker = const TestVSync();
  });

  AnimationController controller() => AnimationController(
    vsync: ticker,
    duration: const Duration(milliseconds: 1200),
  );

  group('pulse', () {
    test('starts a repeating pulse when motion is allowed', () {
      final c = controller();
      addTearDown(c.dispose);

      ReducedMotionPolicy.pulse(c, reduced: false);

      expect(c.isAnimating, isTrue);
    });

    test('parks the pulse when motion is suppressed', () {
      final c = controller();
      addTearDown(c.dispose);
      ReducedMotionPolicy.pulse(c, reduced: false);

      ReducedMotionPolicy.pulse(c, reduced: true);

      expect(c.isAnimating, isFalse);
    });

    test('is idempotent so a rebuild does not restart the pulse', () {
      final c = controller();
      addTearDown(c.dispose);

      ReducedMotionPolicy.pulse(c, reduced: false);
      ReducedMotionPolicy.pulse(c, reduced: false);

      expect(c.isAnimating, isTrue);
    });
  });

  group('pulseValue', () {
    test('a suppressed pulse holds a visible position, not its dimmest frame', () {
      final c = controller();
      addTearDown(c.dispose);

      // c.value is 0.0 here: reading it directly would erase the urgent state.
      expect(c.value, 0.0);
      expect(
        ReducedMotionPolicy.pulseValue(c, reduced: true),
        ReducedMotionPolicy.stillPulseValue,
      );
      expect(ReducedMotionPolicy.stillPulseValue, greaterThan(0.0));
    });

    test('follows the controller when motion is allowed', () {
      final c = controller();
      addTearDown(c.dispose);
      c.value = 0.25;

      expect(ReducedMotionPolicy.pulseValue(c, reduced: false), 0.25);
    });
  });

  group('playOnce', () {
    test('plays a one-shot decoration when motion is allowed', () {
      final c = controller();
      addTearDown(c.dispose);

      ReducedMotionPolicy.playOnce(c, reduced: false);

      expect(c.isAnimating, isTrue);
    });

    test('does nothing when motion is suppressed', () {
      final c = controller();
      addTearDown(c.dispose);

      ReducedMotionPolicy.playOnce(c, reduced: true);

      expect(c.isAnimating, isFalse);
      expect(c.value, 0.0);
    });
  });

  group('isReduced', () {
    testWidgets('reads the platform preference', (tester) async {
      late bool reduced;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reduced = ReducedMotionPolicy.isReduced(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(reduced, isTrue);
    });

    testWidgets('absent MediaQuery means motion is allowed', (tester) async {
      late bool reduced;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            reduced = ReducedMotionPolicy.isReduced(context);
            return const SizedBox();
          },
        ),
      );

      expect(reduced, isFalse);
    });
  });
}
