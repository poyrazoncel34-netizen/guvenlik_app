import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomePage PanicButton integration', () {
    test('passes hasEmergencyContact to PanicButton', () {
      final source = File('lib/screens/home_page.dart').readAsStringSync();
      expect(source.contains('hasEmergencyContact:'), isTrue,
          reason: 'home_page.dart must pass hasEmergencyContact: to PanicButton so arming is blocked when no contact exists');
    });

    test('passes onNoContact callback to PanicButton', () {
      final source = File('lib/screens/home_page.dart').readAsStringSync();
      expect(source.contains('onNoContact:'), isTrue,
          reason: 'home_page.dart must pass onNoContact: to PanicButton to handle no-contact taps');
    });
  });
}
