// Y-12: the FFI binding behind SafetyClock.system on Android. The suspend
// behaviour itself is device-only (an emulator does not suspend like a phone);
// what a host can prove is that the binding reads a real clock through libc
// with the timespec layout `Long, Long` and that it advances with real time.

import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/boot_clock.dart';

/// A sleep-counting clock this host's libc has: CLOCK_MONOTONIC on Darwin
/// (counts sleep there), CLOCK_BOOTTIME on Linux (the Android id).
int? get _hostClockId => Platform.isMacOS
    ? 6
    : Platform.isLinux
    ? 7
    : null;

void main() {
  test(
    'reads a real clock through libc and advances with real time',
    () async {
      final read = BootClock.open(
        DynamicLibrary.process(),
        clockId: _hostClockId!,
      );
      expect(read, isNotNull);

      final watch = Stopwatch()..start();
      final first = read!()!;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final second = read()!;
      watch.stop();

      final advancedUs = second - first;
      expect(advancedUs, greaterThanOrEqualTo(100000));
      expect(advancedUs, lessThanOrEqualTo(watch.elapsedMicroseconds + 50000));
    },
    skip: _hostClockId == null ? 'no known sleep-counting clock id' : false,
  );

  test(
    'an unknown clock id yields no reader instead of a broken one',
    () {
      expect(BootClock.open(DynamicLibrary.process(), clockId: 99999), isNull);
    },
    skip: _hostClockId == null ? 'no libc clock_gettime' : false,
  );

  test('only Android uses the boot clock, so hosts keep the Stopwatch', () {
    expect(BootClock.forPlatform(), Platform.isAndroid ? isNotNull : isNull);
  });
}
