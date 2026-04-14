// Verifies that the Play build does not include third-party crash reporting.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main.dart does not initialize SentryFlutter', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source.contains('SentryFlutter.init'),
      isFalse,
      reason:
          'Public Play privacy/data-safety copy says crash reporting is not used.',
    );
  });

  test('pubspec does not depend on sentry_flutter', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('sentry_flutter'),
      isFalse,
      reason:
          'Crash-reporting SDKs must not be present unless Play Data Safety is updated.',
    );
  });
}
