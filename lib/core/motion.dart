// ============================================================================
// MOTION — the app's shared timing scale
// ============================================================================
// Twenty distinct animation durations were scattered across the app (200ms in
// seven places, 500ms in ten, 300ms in seven, 150, 250, 120, 400...). Each one
// looked fine on its own; together they had no rhythm, and inconsistent timing
// is what reads as unpolished even when every individual animation is smooth.
//
// Three steps is deliberate. A scale with more rungs invites picking a new
// number instead of choosing between existing ones, which is how the twenty
// happened.
//
// Division of labour: this file answers "how long" and, for the springs below,
// "how it settles". [ReducedMotionPolicy] answers "at all?" — it reads the
// platform reduce-motion preference and parks or suppresses animations. Neither
// one overrides the other; a screen asks both.
//
// Durations and springs are not interchangeable. A duration is right when the
// app decides the motion (a screen arriving). A spring is right when the USER
// decides it — anything released, dragged or interrupted — because a spring
// starts from wherever the value currently is instead of cutting to a new
// timeline. A hard cut at the end of a gesture is what reads as "frozen".
//
// NOT covered here, on purpose:
//   * Ambient pulses (a splash logo, the countdown's urgent glow, the panic
//     button's armed breath). Those are per-screen character and legitimately
//     differ; the countdown glow at 1400ms and the armed pulse at 1200ms are
//     tuned choices, not drift. Forcing them onto one rung would be worse.
//   * Timers, timeouts and delays. Those are behaviour, not motion.
// ============================================================================

import 'package:flutter/animation.dart';

abstract final class Motion {
  // ── Durations ────────────────────────────────────────────────────────────

  /// Small state changes the eye tracks but does not wait for: a button press,
  /// a chip toggle, an icon swap.
  static const Duration fast = Duration(milliseconds: 140);

  /// The default. Cards, sheets, list items, the tab crossfade.
  static const Duration base = Duration(milliseconds: 240);

  /// A whole screen replacing another.
  static const Duration slow = Duration(milliseconds: 360);

  /// The dispatch path: panic press -> countdown -> call attempt.
  ///
  /// Not a rung on the scale and not a tuning knob. Screen time before the
  /// countdown can arm is latency on the one path where latency matters, and
  /// the user has already committed by completing the hold gesture. Pinned by
  /// test/screens/dispatch_path_latency_contract_test.dart.
  static const Duration dispatch = Duration.zero;

  // ── Curves ───────────────────────────────────────────────────────────────

  /// Things arriving. Decelerating: fast at the start, settling at the end.
  static const Curve enter = Curves.easeOutCubic;

  /// Things leaving.
  static const Curve exit = Curves.easeInCubic;

  /// Continuous, non-directional motion (breathing, shimmer). Symmetric so it
  /// has no beginning or end to notice.
  static const Curve ambient = Curves.easeInOut;

  // ── Springs ──────────────────────────────────────────────────────────────
  //
  // Parameterised the way Apple's designers do it (damping ratio + response in
  // seconds) rather than by raw stiffness, then converted: for a unit mass a
  // response T means stiffness = (2*pi/T)^2.
  //
  // Deliberately only ONE spring here, critically damped. Overshoot is the
  // right answer when a gesture carried momentum, and the wrong answer on every
  // control this app owns — a bouncy safety button reads as playful. Add a
  // bouncy rung only when there is a flick to justify it.

  /// Critically damped, ~0.4s response. Matches Apple's "move / reposition"
  /// spring. No overshoot: the value settles onto the target and stops.
  static final SpringDescription settle = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 247, // (2*pi/0.4)^2, rounded
    ratio: 1,
  );
}
