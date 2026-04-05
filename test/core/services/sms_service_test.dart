import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/sms_service.dart';

void main() {
  group('SmsComposeResult.statusMessage', () {
    test('nativeDispatched status message should use localization key not hardcoded Turkish', () {
      final result = SmsComposeResult.nativeDispatched(['+905551234567']);
      // When easy_localization is not initialized, .tr() returns the key itself.
      // So if the code correctly uses 'sms_native_dispatched'.tr(), we get the key back.
      // The bug is it returns hardcoded 'Yerel SMS gonderimi baslatildi' instead.
      expect(
        result.statusMessage,
        equals('sms_native_dispatched'),
        reason:
            'statusMessage should use sms_native_dispatched.tr() localization key',
      );
    });
  });

  group('SmsService source has no hardcoded Turkish strings', () {
    test('sms_service.dart should not contain hardcoded Turkish error messages', () {
      final source = File('lib/core/services/sms_service.dart').readAsStringSync();
      // These hardcoded Turkish strings should be replaced with .tr() localization keys
      expect(source, isNot(contains('SMS göndermek için')),
          reason: 'KVKK consent error should use a localization key');
      expect(source, isNot(contains('Ucak modu')),
          reason: 'Airplane mode error should use a localization key');
      expect(source, isNot(contains('SIM kart')),
          reason: 'SIM unavailable error should use a localization key');
    });
  });
}
