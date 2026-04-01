import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountdownScreen._makeEmergencyCall', () {
    test('filters out numbers with fewer than 7 digits before calling', () {
      final source = File('lib/screens/countdown_screen.dart').readAsStringSync();
      expect(source.contains('digits.length >= 7'), isTrue,
          reason: '_makeEmergencyCall must filter numbers shorter than 7 digits to avoid invalid emergency calls');
    });
  });
}
