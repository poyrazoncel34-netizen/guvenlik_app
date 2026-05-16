import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmergencyTriggerHost platform events listener', () {
    test('listener callback should have try-catch error handling', () {
      final source = File(
        'lib/core/widgets/emergency_trigger_host.dart',
      ).readAsStringSync();
      final listenerStart = source.indexOf('.listen((event) async');
      expect(
        listenerStart,
        isNot(-1),
        reason: 'platform events listener should exist',
      );
      final callback = source.substring(listenerStart, listenerStart + 500);
      expect(
        callback,
        contains('try {'),
        reason:
            'platform events listener must have try-catch to prevent listener death',
      );
    });
  });
}
