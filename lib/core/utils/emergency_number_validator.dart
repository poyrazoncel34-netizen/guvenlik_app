import '../constants/app_constants.dart';
import '../services/android_intent_service.dart';

class EmergencyNumberValidator {
  EmergencyNumberValidator._();

  static const int minUserContactDigits = 7;
  static const int maxUserContactDigits = 15;

  static bool isOfficialEmergencyShortCode(String number) {
    return AppConstants.officialEmergencyShortCodes.contains(
      _digitsOnly(number),
    );
  }

  static bool isUserContactPhoneNumber(String number) {
    final digitCount = _digitsOnly(number).length;
    return digitCount >= minUserContactDigits &&
        digitCount <= maxUserContactDigits;
  }

  static bool isCallableEmergencyTarget(String number) {
    return isOfficialEmergencyShortCode(number) ||
        isUserContactPhoneNumber(number);
  }

  static String _digitsOnly(String number) {
    return AndroidIntentService.normalizePhoneNumber(
      number,
    ).replaceAll(RegExp(r'\D'), '');
  }
}
