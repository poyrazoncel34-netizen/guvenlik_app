// Verifies that main.dart wraps runApp with SentryFlutter.init for optional
// crash reporting (KVKK-safe: only active when SENTRY_DSN env var is set).
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main.dart wraps app with SentryFlutter.init', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source.contains('SentryFlutter.init'),
      isTrue,
      reason: 'main.dart must wrap runApp with SentryFlutter.init',
    );
  });
}
