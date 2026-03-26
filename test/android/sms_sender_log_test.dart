import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// S3: SmsSender must not log phone numbers or exception messages that may
/// contain PII. Only safe, generic error messages should appear in logcat.
void main() {
  test('SmsSender should not interpolate exception messages into logs', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/SmsSender.kt',
    ).readAsStringSync();

    expect(
      source.contains(r'${e.message}'),
      isFalse,
      reason:
          'SmsSender must not interpolate exception messages into logs — '
          'they may contain phone numbers (PII leak to logcat)',
    );
  });
}
