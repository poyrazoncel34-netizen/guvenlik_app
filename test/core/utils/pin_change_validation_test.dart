import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/utils/validators.dart';

void main() {
  group('PIN change validation', () {
    test('empty string is invalid', () {
      expect(Validators.isValidPin(''), isFalse);
    });

    test('non-pattern 4 digits is valid', () {
      expect(Validators.isValidPin('4937'), isTrue);
    });

    test('weak PINs are invalid', () {
      for (final pin in [
        '0000',
        '1111',
        '9999',
        '1234',
        '4321',
        '1122',
        '1212',
        '7777',
        '2580',
        '0852',
        '2345',
        '9876',
      ]) {
        expect(Validators.isValidPin(pin), isFalse, reason: pin);
      }
    });

    test('3 digits is invalid', () {
      expect(Validators.isValidPin('123'), isFalse);
    });

    test('5 digits is invalid', () {
      expect(Validators.isValidPin('12345'), isFalse);
    });

    test('letters mixed with digits is invalid', () {
      expect(Validators.isValidPin('ab12'), isFalse);
    });
  });
}
