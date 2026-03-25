// Widget smoke test: SafeWalkScreen source contracts.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SafeWalkScreen', () {
    test('safe_walk_screen source file exists', () {
      expect(File('lib/screens/safe_walk_screen.dart').existsSync(), isTrue);
    });

    test('SafeWalkScreen uses a countdown timer (Timer or AnimationController)', () {
      final source = File('lib/screens/safe_walk_screen.dart').readAsStringSync();
      expect(
        source.contains('Timer') || source.contains('AnimationController'),
        isTrue,
        reason: 'SafeWalkScreen must use a timer for the countdown',
      );
    });
  });
}
