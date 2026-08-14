import 'package:flutter/material.dart';

/// Guarantees a >= [minSize] interactive and semantic area around a control
/// that is deliberately drawn smaller, WITHOUT enlarging what is painted.
///
/// ## Why this exists
///
/// Two switches in this app are wrapped in `Transform.scale(scale: 0.85)`.
/// A transform scales the hit-test region together with the pixels, so the
/// Material switch's built-in 48 dp `MaterialTapTargetSize.padded` box was
/// being shrunk along with the artwork. Measured from the real semantics tree
/// on an API 36 emulator (`adb shell uiautomator dump`, density 420 /
/// dpr 2.625): **51.0 x 40.8 dp**, and 51.0 x 28.2 dp for the compact variant.
/// Android's own accessibility guidance asks for 48 x 48 dp.
///
/// The number was NOT inferred from the icon size -- inferring is how the
/// undersized targets survived the previous pass. It came from the rendered
/// node's own bounds.
///
/// ## How it keeps the visual identical
///
/// The scaled control still paints exactly as before and stays on top, so it
/// keeps its own gestures (a switch's drag, its ripple, its animation). A
/// transparent [GestureDetector] fills the enlarged box BEHIND it and catches
/// the taps that land in the newly reachable margin. [MergeSemantics] then
/// collapses the pair into ONE accessibility node, so a screen reader hears a
/// single control of the full size instead of a small one plus an invisible
/// sibling.
///
/// The box only ever GROWS to [minSize]; a control already larger is left
/// alone, which is why the constraint is a minimum rather than a fixed size.
class MinimumTapTarget extends StatelessWidget {
  const MinimumTapTarget({
    super.key,
    required this.onTap,
    required this.child,
    this.minSize = 48.0,
  });

  /// Fired for taps that land in the padding around [child]. Taps on [child]
  /// itself are still handled by [child], so its own behaviour is untouched.
  final VoidCallback? onTap;

  final Widget child;

  /// Android's recommended minimum interactive dimension.
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: const SizedBox.expand(),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
