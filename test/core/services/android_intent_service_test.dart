import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/android_intent_service.dart';

void main() {
  group('AndroidIntentService.normalizePhoneNumber', () {
    test('removes dots from phone number', () {
      expect(
        AndroidIntentService.normalizePhoneNumber('0536.449.90.39'),
        '05364499039',
      );
    });
  });
}
