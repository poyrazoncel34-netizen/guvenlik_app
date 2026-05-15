import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountdownScreen._makeEmergencyCall', () {
    test('uses callable emergency target validation before calling', () {
      final source = File(
        'lib/screens/countdown_screen.dart',
      ).readAsStringSync();

      expect(
        source.contains('EmergencyNumberValidator.isCallableEmergencyTarget'),
        isTrue,
        reason:
            'countdown_screen must allow official short codes while still '
            'validating normal contact numbers before dispatch',
      );
      expect(
        source.contains('digits.length >= 7'),
        isFalse,
        reason:
            'raw length filtering rejects official emergency short codes '
            'such as 112',
      );
    });
  });
}
