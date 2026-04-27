import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forgot PIN reset returns to Splash instead of MainNavigation', () {
    final source = File(
      'lib/screens/app_unlock_screen.dart',
    ).readAsStringSync();

    expect(source, contains("import 'splash_screen.dart';"));
    expect(source, contains('pageBuilder: (_, _, _) => const SplashScreen()'));
    expect(
      source,
      isNot(contains('pageBuilder: (_, _, _) => const MainNavigation()')),
      reason:
          'After destructive reset, the app must restart through Splash so '
          'legal/onboarding/PIN setup cannot be bypassed.',
    );
  });
}
