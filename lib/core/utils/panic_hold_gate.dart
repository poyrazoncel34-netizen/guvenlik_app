/// Pure timing contract for the sighted panic-button gesture.
///
/// The widget measures elapsed time with [Stopwatch], so wall-clock changes
/// cannot shorten or complete an armed hold. Keeping the threshold here makes
/// the safety invariant independently testable without platform channels.
abstract final class PanicHoldGate {
  static const requiredDuration = Duration(seconds: 3);

  static bool isComplete(Duration elapsed) {
    return !elapsed.isNegative && elapsed >= requiredDuration;
  }

  static double progress(Duration elapsed) {
    if (elapsed <= Duration.zero) return 0;
    final ratio = elapsed.inMicroseconds / requiredDuration.inMicroseconds;
    return ratio.clamp(0.0, 1.0);
  }
}
