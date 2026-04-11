import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('countdown_screen no longer builds emergency messages', () {
    final source = File('lib/screens/countdown_screen.dart').readAsStringSync();

    expect(
      source.contains('buildCountdownMessage') ||
          source.contains('composeSms') ||
          source.contains('sendSms'),
      isFalse,
      reason:
          'Countdown must be call-only; message building must not block or imply delivery.',
    );
  });
}
