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

    test('countdownSeconds is 10', () {
      expect(AppConstants.countdownSeconds, 10);
    });

    test('maxEmergencyContacts is 5', () {
      expect(AppConstants.maxEmergencyContacts, 5);
    });

    test('privacyPolicyUrl is a valid HTTPS URL', () {
      expect(AppConstants.privacyPolicyUrl, startsWith('https://'));
    });

    test('supportEmail is set', () {
      expect(AppConstants.supportEmail, isNotEmpty);
      expect(AppConstants.supportEmail, contains('@'));
    });

    test('all SharedPreferences keys are unique', () {
      final keys = [
        AppConstants.prefProfileName,
        AppConstants.prefProfileEmail,
        AppConstants.prefNotifications,
        AppConstants.prefSound,
        AppConstants.prefPinSetupDone,
        AppConstants.prefOnboardingDone,
        AppConstants.prefLegalDisclaimerAccepted,
        AppConstants.prefTermsVersion,
        AppConstants.prefNotificationPermissionPrompted,
        AppConstants.prefDemoMode,
        AppConstants.prefVolumeTrigger,
        // Deprecated legacy medical keys retained for one-time cleanup only.
        // ignore: deprecated_member_use_from_same_package
        AppConstants.prefBloodType,
        // ignore: deprecated_member_use_from_same_package
        AppConstants.prefAllergies,
        // ignore: deprecated_member_use_from_same_package
        AppConstants.prefMedicalConditions,
        // ignore: deprecated_member_use_from_same_package
        AppConstants.prefEmergencyNotes,
      ];
      expect(
        keys.toSet().length,
        keys.length,
        reason: 'Duplicate pref key found',
      );
    });
  });
}
