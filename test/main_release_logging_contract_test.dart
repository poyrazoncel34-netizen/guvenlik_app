import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source contract for release log hygiene in `lib/main.dart`.
///
/// Behaviour verified here (release-only, so asserted at the source level the
/// same way as the RevenueCat subscription contract test):
///   1. `debugPrint` is silenced in release builds (no app logs to logcat).
///   2. The real console sink is captured BEFORE silencing.
///   3. Flutter framework errors are still forwarded to logcat via
///      `FlutterError.presentError`, so the Play Pre-launch Report keeps
///      surfacing Dart-side framework errors.
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

    test('original console sink is captured before silencing', () {
      expect(
        source,
        contains('final consoleSink = debugPrint;'),
      );
    });

    test('framework errors are still forwarded to logcat for Pre-launch', () {
      // Real sink restored around presentError in release.
      expect(source, contains('debugPrint = consoleSink;'));
      expect(source, contains('FlutterError.presentError(details);'));
    });
  });
}
