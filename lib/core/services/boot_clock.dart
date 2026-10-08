import 'dart:ffi';
import 'dart:io' show Platform;

/// Microseconds on a clock, or null when the read failed.
typedef MicrosReader = int? Function();

typedef _ClockGettimeC = Int Function(Int clockId, Pointer<Long> timespec);
typedef _ClockGettime = int Function(int clockId, Pointer<Long> timespec);
typedef _MallocC = Pointer<Void> Function(Size bytes);
typedef _Malloc = Pointer<Void> Function(int bytes);

/// CLOCK_BOOTTIME read through libc (audit Y-12).
///
/// It is the clock behind Android's `SystemClock.elapsedRealtime()`, the one
/// every native safety alarm is scheduled on, and unlike a Dart [Stopwatch]
/// (CLOCK_MONOTONIC) it keeps counting while the device sleeps.
abstract final class BootClock {
  /// Linux/Android `CLOCK_BOOTTIME`.
  static const int _clockBoottime = 7;

  /// The boot clock on Android; null anywhere else or when it cannot be read.
  static MicrosReader? forPlatform() => Platform.isAndroid
      ? open(DynamicLibrary.open('libc.so'), clockId: _clockBoottime)
      : null;

  /// A reader for [clockId] through [libc]'s `clock_gettime`, or null when
  /// the symbols are missing or a first read fails.
  ///
  /// `struct timespec` is `{time_t; long}` and `time_t` is `long` on Android
  /// and Darwin, so two [Long]s match it on 32- and 64-bit ABIs alike. The
  /// buffer is allocated once and lives as long as the isolate.
  static MicrosReader? open(DynamicLibrary libc, {required int clockId}) {
    final _ClockGettime clockGettime;
    final Pointer<Long> timespec;
    try {
      clockGettime = libc.lookupFunction<_ClockGettimeC, _ClockGettime>(
        'clock_gettime',
        isLeaf: true,
      );
      final malloc = libc.lookupFunction<_MallocC, _Malloc>('malloc');
      timespec = malloc(2 * sizeOf<Long>()).cast<Long>();
    } on ArgumentError {
      return null;
    }
    if (timespec == nullptr) return null;
    int? read() {
      if (clockGettime(clockId, timespec) != 0) return null;
      return timespec[0] * Duration.microsecondsPerSecond +
          timespec[1] ~/ 1000; // ns -> us
    }

    return read() == null ? null : read;
  }
}
