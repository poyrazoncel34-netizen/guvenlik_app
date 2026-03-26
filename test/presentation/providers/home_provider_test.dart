import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeProvider location share timer', () {
    test('timer callback should have try-catch to prevent unhandled exceptions', () {
      final source = File('lib/presentation/providers/home_provider.dart').readAsStringSync();
      // Find the location share timer callback
      final timerStart = source.indexOf('_locationShareTimer = Timer.periodic');
      expect(timerStart, isNot(-1), reason: 'location share timer should exist');
      // The callback should have try-catch wrapping
      final callback = source.substring(timerStart, timerStart + 400);
      expect(callback, contains('try {'),
          reason: 'location share timer callback must have try-catch for resilience');
    });
  });
}
