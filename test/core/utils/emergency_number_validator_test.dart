import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/utils/emergency_number_validator.dart';

void main() {
  group('EmergencyNumberValidator', () {
    test('official emergency short codes are NOT callable targets', () {
      // 112 and friends are never synthesized, coerced, or accepted as an
      // auto-dial target — only real user contact numbers are callable.
      expect(
        EmergencyNumberValidator.isCallableEmergencyTarget('112'),
        isFalse,
      );
      expect(
        EmergencyNumberValidator.isCallableEmergencyTarget('911'),
        isFalse,
      );
      expect(
        EmergencyNumberValidator.isCallableEmergencyTarget('999'),
        isFalse,
      );
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

    test('rejects overlong emergency contact phone numbers', () {
      expect(
        EmergencyNumberValidator.isUserContactPhoneNumber('123456789012345'),
        isTrue,
      );
      expect(
        EmergencyNumberValidator.isUserContactPhoneNumber('1234567890123456'),
        isFalse,
      );
      expect(
        EmergencyNumberValidator.isCallableEmergencyTarget(
          '6565665655665656565656565656',
        ),
        isFalse,
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

    test('rejects URI syntax extensions pauses and control characters', () {
      const unsafeTargets = <String>[
        'tel:+905551234567',
        '+905551234567?body=999',
        '+905551234567;ext=123',
        '+905551234567,123',
        '+905551234567#123',
        '+905551234567*123',
        '+905551234567\r\n999',
        '90+5551234567',
      ];

      for (final target in unsafeTargets) {
        expect(
          EmergencyNumberValidator.isCallableEmergencyTarget(target),
          isFalse,
          reason: 'unsafe syntax became callable: ${target.codeUnits}',
        );
      }
    });

    test('callable target is exactly a user contact phone number', () {
      // No short-code allow-list any more: callability == user contact number.
      expect(
        EmergencyNumberValidator.isUserContactPhoneNumber('05364499039'),
        isTrue,
      );
      expect(
        EmergencyNumberValidator.isCallableEmergencyTarget('05364499039'),
        isTrue,
      );
      expect(EmergencyNumberValidator.isUserContactPhoneNumber('112'), isFalse);
    });
  });
}
