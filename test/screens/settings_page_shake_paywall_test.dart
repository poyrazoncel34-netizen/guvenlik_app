import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings_page does not expose active shake trigger controls', () {
    final source = File('lib/screens/settings_page.dart').readAsStringSync();
    expect(
      source.contains('armShake') || source.contains('settings_shake_title'),
      isFalse,
      reason:
          'Shake trigger is disabled in this release and must not expose an active settings path.',
    );
  });
}
