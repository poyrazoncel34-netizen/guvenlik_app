/// Turns an absolute safety deadline into the number the countdown UI shows.
///
/// The native session is armed with an ABSOLUTE deadline and its alarm fires
/// on that instant. The screen used to count ten one-second ticks starting
/// after the arm round trip returned, so the UI ran later than the session it
/// was describing: with a slow channel it could still display "1" while the
/// call was already being placed, and the visible cancel window was shorter
/// than it looked. Deriving the display from the same deadline removes the
/// drift by construction.
class CountdownClock {
  const CountdownClock._();

  /// Whole seconds left, rounded UP so the display never shows a second the
  /// user has already run out of, and clamped at zero.
  ///
  /// Zero means "dispatch now", so it is decided in MICROseconds. Truncating
  /// to milliseconds reported zero up to 1 ms before the deadline, while
  /// native still refused (`currentTimeMillis() < finalDeadlineMs`); the panic
  /// path read that refusal as unknown and opened the dialer just before the
  /// native alarm placed the automatic request too.
  static int secondsUntil(DateTime deadline, {DateTime? now}) {
    final remainingUs = deadline
        .difference(now ?? DateTime.now())
        .inMicroseconds;
    if (remainingUs <= 0) return 0;
    return (remainingUs / Duration.microsecondsPerSecond).ceil();
  }
}
