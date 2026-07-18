import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source contract for release log hygiene in `lib/main.dart`.
///
/// Behaviour verified here (release-only, so asserted at the source level the
/// same way as the RevenueCat subscription contract test):
///   1. `debugPrint` is silenced in release builds (no app logs to logcat).
///   2. Raw framework exception text/stacks are not restored to release logcat.
///   3. Local diagnostics persist allowlisted codes instead of arbitrary data.
void main() {
  group('main.dart release logging hygiene', () {
    late String source;

    setUp(() {
      source = File('lib/main.dart').readAsStringSync();
    });

    test('debugPrint is silenced in release builds', () {
      expect(source, contains('if (kReleaseMode) {'));
      expect(
        source,
        contains('debugPrint = (String? message, {int? wrapWidth}) {};'),
      );
    });

    test('release never restores a raw console sink', () {
      expect(source, isNot(contains('final consoleSink = debugPrint;')));
      expect(source, isNot(contains('debugPrint = consoleSink;')));
    });

    test(
      'raw framework presentation is debug-only and codes are persisted',
      () {
        expect(source, contains('if (!kReleaseMode) {'));
        expect(source, contains('FlutterError.presentError(details);'));
        expect(source, contains('LocalErrorCode.flutterFrameworkUnhandled'));
        expect(source, contains('LocalErrorCode.platformDispatcherUnhandled'));
        expect(source, contains('return kReleaseMode;'));
      },
    );
  });
}
