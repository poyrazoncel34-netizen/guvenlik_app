import '../constants/app_constants.dart';
import '../services/android_intent_service.dart';

class EmergencyNumberValidator {
  EmergencyNumberValidator._();

  static bool isOfficialEmergencyShortCode(String number) {
    return AppConstants.officialEmergencyShortCodes.contains(
      _digitsOnly(number),
    );
  }

  static bool isUserContactPhoneNumber(String number) {
    return _digitsOnly(number).length >= 7;
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
