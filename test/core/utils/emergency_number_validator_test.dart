import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/utils/emergency_number_validator.dart';

void main() {
  group('EmergencyNumberValidator', () {
    test('allows official emergency short codes', () {
      expect(EmergencyNumberValidator.isCallableEmergencyTarget('112'), isTrue);
      expect(EmergencyNumberValidator.isCallableEmergencyTarget('911'), isTrue);
      expect(EmergencyNumberValidator.isCallableEmergencyTarget('999'), isTrue);
    });

    test('rejects random three-digit numbers', () {
      expect(
        EmergencyNumberValidator.isCallableEmergencyTarget('123'),
        isFalse,
      );
      expect(
        EmergencyNumberValidator.isCallableEmergencyTarget('777'),
        isFalse,
      );
    });

    test('allows normal emergency contact phone numbers', () {
      expect(
        EmergencyNumberValidator.isCallableEmergencyTarget('0536 449 90 39'),
        isTrue,
      );
      expect(
        EmergencyNumberValidator.isCallableEmergencyTarget('+90 536 449 90 39'),
        isTrue,
      );
    });

    test('rejects empty and invalid numbers', () {
      expect(EmergencyNumberValidator.isCallableEmergencyTarget(''), isFalse);
      expect(
        EmergencyNumberValidator.isCallableEmergencyTarget('abc'),
        isFalse,
      );
      expect(EmergencyNumberValidator.isCallableEmergencyTarget('12'), isFalse);
    });

    test('keeps official emergency short-code validation separate', () {
      expect(
        EmergencyNumberValidator.isOfficialEmergencyShortCode('112'),
        isTrue,
      );
      expect(
        EmergencyNumberValidator.isOfficialEmergencyShortCode('05364499039'),
        isFalse,
      );
      expect(
        EmergencyNumberValidator.isUserContactPhoneNumber('05364499039'),
        isTrue,
      );
    });
  });
}
