import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('appName is KoruBeni', () {
      expect(AppConstants.appName, 'KoruBeni');
    });
    test('pinLength is 4', () {
      expect(AppConstants.pinLength, 4);
    });
    test('maxEmergencyContacts is 5', () {
      expect(AppConstants.maxEmergencyContacts, 5);
    });
    test('countdownSeconds is 10', () {
      expect(AppConstants.countdownSeconds, 10);
    });
  });
}
