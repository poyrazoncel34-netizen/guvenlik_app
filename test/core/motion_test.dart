import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/motion.dart';

/// The scale exists to stop timing drift. These tests pin the properties that
/// make it a scale rather than four more magic numbers.
void main() {
  group('the rungs are ordered and distinct', () {
    test('fast < base < slow', () {
      expect(Motion.fast, lessThan(Motion.base));
      expect(Motion.base, lessThan(Motion.slow));
    });

    test('every rung is perceptible but not sluggish', () {
      for (final rung in <Duration>[Motion.fast, Motion.base, Motion.slow]) {
        // Below ~100ms a transition reads as a jump; above ~400ms the user is
        // waiting for the interface instead of using it.
        expect(rung.inMilliseconds, greaterThanOrEqualTo(100));
        expect(rung.inMilliseconds, lessThanOrEqualTo(400));
      }
    });

    test('the rungs are far enough apart to be a real choice', () {
      // Rungs closer than ~80ms are indistinguishable, which invites adding a
      // fourth instead of picking one of three.
      expect(
        Motion.base.inMilliseconds - Motion.fast.inMilliseconds,
        greaterThanOrEqualTo(80),
      );
      expect(
        Motion.slow.inMilliseconds - Motion.base.inMilliseconds,
        greaterThanOrEqualTo(80),
      );
    });
  });

  group('the dispatch path is not a rung', () {
    test('dispatch is exactly zero', () {
      expect(Motion.dispatch, Duration.zero);
    });

    test('dispatch is shorter than everything on the scale', () {
      expect(Motion.dispatch, lessThan(Motion.fast));
    });
  });

  group('curves carry direction', () {
    test('entering decelerates, leaving accelerates', () {
      // An entering element should cover most of its distance early and settle;
      // a leaving one should do the opposite.
      expect(Motion.enter.transform(0.5), greaterThan(0.5));
      expect(Motion.exit.transform(0.5), lessThan(0.5));
    });

    test('ambient motion is symmetric so it has no start or end', () {
      final early = Motion.ambient.transform(0.25);
      final late_ = Motion.ambient.transform(0.75);
      expect(early + late_, closeTo(1.0, 0.001));
    });

    test('no rung overshoots its target', () {
      // Overshoot reads as playful. This app is not.
      for (final curve in <Curve>[Motion.enter, Motion.exit, Motion.ambient]) {
        for (var t = 0.0; t <= 1.0; t += 0.05) {
          final value = curve.transform(t);
          expect(value, inInclusiveRange(0.0, 1.0), reason: 't=$t');
        }
      }
    });
  });
}
