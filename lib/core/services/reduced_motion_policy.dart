// ============================================================================
// REDUCED MOTION POLICY
// ============================================================================
// One place that decides whether decorative motion runs, so the panic-moment
// screens do not each re-derive it.
//
// Two separate reasons this exists:
//
//   1. Accessibility. When the platform reports "reduce motion", repeating
//      pulses and bounces must stop. Suppressing them costs nothing here: the
//      countdown number and the haptic channel already carry the information,
//      so the animation is decoration, not content.
//
//   2. Panic-moment readability. A fast blink raises arousal and makes a number
//      harder to read at the exact moment it matters most, so the armed states
//      breathe slowly instead of flashing. That part is a duration choice at
//      the call sites; this file owns the on/off decision and what a stopped
//      animation should look like.
// ============================================================================

import 'package:flutter/material.dart';

abstract final class ReducedMotionPolicy {
  /// Value a suppressed pulse holds: mid-travel, so an urgent state stays
  /// visible instead of collapsing to its dimmest frame.
  static const double stillPulseValue = 0.5;

  /// Reads the platform preference. Absent MediaQuery means "no preference
  /// expressed", which is motion allowed.
  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Drives a repeating pulse, or parks it when motion is suppressed.
  /// Idempotent: safe to call on every didChangeDependencies.
  ///
  /// A suppressed pulse is parked AT [stillPulseValue], not merely stopped.
  /// `stop()` alone leaves the controller wherever it happened to be — which,
  /// for a controller that never started, is 0.0, i.e. the dimmest frame of the
  /// animation. Every consumer in this app reads `controller.value` straight
  /// into an alpha, a scale or a radius, so stopping without parking renders
  /// the armed state INVISIBLE for exactly the users who asked for less motion.
  /// Parking here fixes all of them at once instead of at eight call sites.
  static void pulse(AnimationController controller, {required bool reduced}) {
    if (reduced) {
      controller.stop();
      controller.value = stillPulseValue;
      return;
    }
    if (!controller.isAnimating) controller.repeat(reverse: true);
  }

  /// Drives a one-directional repeating loop (a shimmer sweep), or parks it.
  ///
  /// Separate from [pulse] because a sweep has no meaningful mid-travel state:
  /// parking a shimmer at 0.5 leaves a highlight frozen across the middle of
  /// the surface, which reads as a rendering fault rather than as a still frame.
  static void loop(AnimationController controller, {required bool reduced}) {
    if (reduced) {
      controller.stop();
      controller.value = 0;
      return;
    }
    if (!controller.isAnimating) controller.repeat();
  }

  /// Current pulse position, or the parked position when suppressed.
  static double pulseValue(
    AnimationController controller, {
    required bool reduced,
  }) => reduced ? stillPulseValue : controller.value;

  /// Plays a one-shot decorative animation unless motion is suppressed.
  static void playOnce(AnimationController controller, {required bool reduced}) {
    if (reduced) return;
    controller.forward(from: 0);
  }
}
