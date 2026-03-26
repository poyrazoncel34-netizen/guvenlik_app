import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// System 4E: Message building must have a timeout to prevent blocking
/// the emergency flow if GPS hangs.
void main() {
  test('countdown_screen message building should have timeout', () {
    final source = File('lib/screens/countdown_screen.dart').readAsStringSync();

    // Must wrap buildCountdownMessage with timeout
    expect(
      source.contains('buildCountdownMessage') && source.contains('.timeout'),
      isTrue,
      reason:
          'Message building must have timeout — GPS hang must not block emergency',
    );
  });
}
