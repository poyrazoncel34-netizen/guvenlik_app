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
// Division of labour: this file answers "how long". [ReducedMotionPolicy]
// answers "at all?" — it reads the platform reduce-motion preference and parks
// or suppresses animations. Neither one overrides the other; a screen asks both.
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
}
