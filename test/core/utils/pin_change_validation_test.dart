import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/utils/validators.dart';

void main() {
  group('PIN change validation', () {
    test('empty string is invalid', () {
      expect(Validators.isValidPin(''), isFalse);
    });

    test('4 digits is valid', () {
      expect(Validators.isValidPin('1234'), isTrue);
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
