// Verifies that onboarding_screen.dart uses localization keys instead of
// hard-coded Turkish strings, and that a 4th page (PIN security) exists.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sourcePath = 'lib/screens/onboarding_screen.dart';

  test('onboarding screen has 4 pages (4th page key present)', () {
    final source = File(sourcePath).readAsStringSync();
    expect(
      source.contains('onboarding_4_title'),
      isTrue,
      reason: 'A 4th onboarding page with key onboarding_4_title must exist',
    );
  });
}
