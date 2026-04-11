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

    test('turkeyEmergencyNumber is 112', () {
      expect(AppConstants.turkeyEmergencyNumber, '112');
    });

    test('encryptionKeyBase64 returns empty when not set via dart-define', () {
      expect(AppConstants.encryptionKeyBase64, '');
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
        AppConstants.prefLocation,
        AppConstants.prefSound,
        AppConstants.prefVibration,
        AppConstants.prefThemeMode,
        AppConstants.prefPinSetupDone,
        AppConstants.prefOnboardingDone,
        AppConstants.prefLegalDisclaimerAccepted,
        AppConstants.prefKvkkHealthConsentAccepted,
        AppConstants.prefTermsVersion,
        AppConstants.prefRecordingWarningSeen,
        AppConstants.prefNotificationPermissionPrompted,
        AppConstants.prefDemoMode,
        AppConstants.prefVolumeTrigger,
        AppConstants.prefBloodType,
        AppConstants.prefAllergies,
        AppConstants.prefMedicalConditions,
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
