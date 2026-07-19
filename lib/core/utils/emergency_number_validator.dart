import '../services/android_intent_service.dart';

class EmergencyNumberValidator {
  EmergencyNumberValidator._();

  static const int minUserContactDigits = 7;
  static const int maxUserContactDigits = 15;

  static bool isUserContactPhoneNumber(String number) {
    return normalizedCallableTargetOrNull(number) != null;
  }

  /// A target is callable ONLY when it is a real user contact phone number.
  /// Official emergency short codes (112 etc.) are never synthesized, coerced,
  /// or accepted as an auto-dial target by the app.
  static bool isCallableEmergencyTarget(String number) {
    return isUserContactPhoneNumber(number);
  }

  static String? normalizedCallableTargetOrNull(String number) {
    return AndroidIntentService.normalizedCallableOrNull(number);
  }
}
