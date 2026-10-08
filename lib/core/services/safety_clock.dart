/// Time sources for the Dart projections of a safety timer.
///
/// A safety timer is a DURATION. The native session keeps it one: its alarms
/// are ELAPSED_REALTIME and a TIME_SET/TIMEZONE_CHANGED broadcast rebases the
/// stored wall deadlines so the remaining time is preserved. The Dart screens
/// used to divide those wall deadlines by `DateTime.now()` instead, so a clock
/// change moved them and only them (chaos audit 2026-10-08):
///
///  * Y-04 -- a +1 h change during a panic countdown reached zero at once:
///    native, already rebased, refused the dispatch, the refusal read as
///    unknown and the dialer opened, the PIN-cancel pad disappeared, and the
///    native alarm still placed the automatic request at the real deadline;
///  * Y-01 -- Check-In showed "Süre doldu" thirteen minutes early after +1 h,
///    and "134:19" with fourteen minutes left after -2 h.
///
/// [MonotonicDeadline] measures the remaining time on the monotonic clock from
/// the moment it is anchored. The monotonic clock and the wall clock advance
/// at the same (NTP-slewed) rate and differ only by explicit steps, so without
/// a clock change the first zero falls on exactly the instant it did before.
///
/// The monotonic clock must count device sleep, as the wall clock and native's
/// elapsedRealtime do (Y-12): see [SleepCountingMonotonic].
library;

import 'boot_clock.dart';

/// Wall and monotonic time, injectable so a clock change can be tested.
abstract interface class SafetyClock {
  /// The process-wide clock: `DateTime.now()` and the boot clock.
  static const SafetyClock system = _SystemSafetyClock();

  /// Wall-clock time; what native deadlines are expressed in.
  DateTime now();

  /// Time since an arbitrary fixed origin. Never affected by wall-clock
  /// changes; only differences between two readings are meaningful.
  Duration get monotonic;
}

final class _SystemSafetyClock implements SafetyClock {
  const _SystemSafetyClock();

  static final SleepCountingMonotonic _monotonic = SleepCountingMonotonic(
    BootClock.forPlatform(),
  );

  @override
  DateTime now() => DateTime.now();

  @override
  Duration get monotonic => _monotonic.elapsed;
}

/// A monotonic clock that keeps counting while the device sleeps (audit Y-12).
///
/// A Dart [Stopwatch] is CLOCK_MONOTONIC on Android and stops during suspend;
/// native alarms run on elapsedRealtime (CLOCK_BOOTTIME) and do not. After the
/// screen went off a panic countdown still showed seconds and a live PIN pad
/// once native had called, and without a native session the dialer opened
/// only after the un-slept remainder. [boot] is CLOCK_BOOTTIME where it can be
/// read; the [fallback] stopwatch is used where it cannot.
final class SleepCountingMonotonic {
  SleepCountingMonotonic(MicrosReader? boot, {Duration Function()? fallback})
    : _fallback = fallback ?? (Stopwatch()..start()).elapsedFunction {
    // Decided once: adopting a boot clock later would jump the origin by the
    // device's uptime and expire every deadline at once.
    final first = boot?.call();
    _boot = first == null ? null : boot;
    _lastFallback = _fallback();
    _last = first == null ? _lastFallback : Duration(microseconds: first);
  }

  final Duration Function() _fallback;
  late final MicrosReader? _boot;
  late Duration _last;
  late Duration _lastFallback;

  Duration get elapsed {
    final fallbackNow = _fallback();
    final bootUs = _boot?.call();
    // A failed read (or no boot clock) continues from the last reading on the
    // fallback. The boot clock never advances less than the fallback, so a
    // recovered read can only be later: the clock never runs backwards.
    _last = bootUs == null
        ? _last + (fallbackNow - _lastFallback)
        : Duration(microseconds: bootUs);
    _lastFallback = fallbackNow;
    return _last;
  }
}

extension on Stopwatch {
  Duration Function() get elapsedFunction => () => elapsed;
}

/// A deadline that is [remaining] away at construction, measured from then on
/// with the monotonic clock only.
final class MonotonicDeadline {
  /// The monotonic origin is read AFTER whatever wall reading produced
  /// [remaining], so zero can never come before the wall deadline it mirrors
  /// (audit K-03: native refuses a dispatch a microsecond early).
  MonotonicDeadline(this._clock, Duration remaining)
    : _remaining = remaining,
      _origin = _clock.monotonic;

  /// Anchors an absolute wall [deadline], judged now.
  factory MonotonicDeadline.fromWall(SafetyClock clock, DateTime deadline) =>
      MonotonicDeadline(clock, deadline.difference(clock.now()));

  final SafetyClock _clock;
  final Duration _remaining;
  final Duration _origin;

  /// Time left, clamped at zero.
  Duration get remaining {
    final left = _remaining - (_clock.monotonic - _origin);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whole seconds left, rounded UP and decided in microseconds, so the
  /// display never shows a second already spent and zero means "due now".
  int get secondsLeft {
    final remainingUs = remaining.inMicroseconds;
    if (remainingUs <= 0) return 0;
    return (remainingUs / Duration.microsecondsPerSecond).ceil();
  }

  bool get isDue => remaining == Duration.zero;
}
