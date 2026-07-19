import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/screens/contacts_page.dart';

/// S10b regression: a manually entered emergency-contact phone number must be
/// validated for length/format. manualContactPhoneError returns an error
/// translation key for invalid input and null for acceptable numbers.
void main() {
  group('manualContactPhoneError', () {
    test('empty input is rejected', () {
      expect(manualContactPhoneError(''), isNotNull);
      expect(manualContactPhoneError('   '), isNotNull);
    });

    test('letters / junk normalise to no digits and are rejected', () {
      expect(manualContactPhoneError('abcdef'), isNotNull);
    });

    test('URI and extension syntax is rejected before normalization', () {
      expect(manualContactPhoneError('tel:+905551234567'), isNotNull);
      expect(manualContactPhoneError('+905551234567;ext=123'), isNotNull);
      expect(manualContactPhoneError('+905551234567\r\n999'), isNotNull);
    });

    test('too-short numbers (< 7 digits) are rejected', () {
      expect(manualContactPhoneError('12345'), isNotNull);
      expect(manualContactPhoneError('123456'), isNotNull);
    });

    test('too-long numbers (> 15 digits) are rejected', () {
      expect(manualContactPhoneError('1234567890123456'), isNotNull);
    });

    test('valid local number (7-15 digits) is accepted', () {
      expect(manualContactPhoneError('05551234567'), isNull);
      expect(manualContactPhoneError('5551234'), isNull);
    });

    test('valid international (+ prefix) number is accepted', () {
      expect(manualContactPhoneError('+905551234567'), isNull);
    });
  });
}
