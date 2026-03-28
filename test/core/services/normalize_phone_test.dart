import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';

void main() {
  group('normalizePhoneNumber', () {
    test('removes dots from phone number', () {
      expect(normalizePhoneNumber('0536.449.90.39'), '05364499039');
    });
  });
}
