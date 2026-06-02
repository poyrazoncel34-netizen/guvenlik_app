// Widget smoke test: SafeWalkScreen source contracts.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SafeWalkScreen', () {
    test('safe_walk_screen source file exists', () {
      expect(File('lib/screens/safe_walk_screen.dart').existsSync(), isTrue);
    });

    test(
      'SafeWalkScreen drives the countdown via the shared session controller',
      () {
        // SPEC §6: the countdown/grace is owned by CheckInService.safeWalk, not
        // a screen-local Timer.
        final source = File(
          'lib/screens/safe_walk_screen.dart',
        ).readAsStringSync();
        expect(
          source.contains('CheckInService.safeWalk'),
          isTrue,
          reason: 'SafeWalkScreen must use the shared safe-walk controller',
        );
        expect(
          source.contains('_controller.remainingSeconds') ||
              source.contains('_remainingSeconds'),
          isTrue,
          reason: 'SafeWalkScreen renders the controller countdown',
        );
      },
    );

    test('setup and active views are scrollable on small screens', () {
      final source = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();

      expect(source, contains('SingleChildScrollView'));
      expect(source, contains('ConstrainedBox'));
      expect(source, contains('IntrinsicHeight'));
      expect(source, contains('_buildScrollableContent'));
    });
  });
}
