class AppConstants {
  static const String appName = 'KoruBeni';
  // Sürüm bilgisi artık package_info_plus ile alınıyor (PackageInfo.fromPlatform()).
  // Sabit appVersion/buildNumber kaldırıldı – tek kaynak pubspec.yaml.
  static const String supportEmail = 'korubeni.destek@gmail.com';

  /// Encryption key is loaded from dart-define at build time.
  /// Build with: --dart-define=ENCRYPTION_KEY=your_base64_key
  /// Falls back to empty string — EncryptionService must handle gracefully.
  static String get encryptionKeyBase64 =>
      const String.fromEnvironment('ENCRYPTION_KEY', defaultValue: '');

  // PIN
  static const int pinLength = 4;
  static const int countdownSeconds = 10;

  // Limits
  static const int maxEmergencyContacts = 5;
  static const String turkeyEmergencyNumber = '112';

  // SharedPreferences keys (non-sensitive)
  static const String prefProfileName = 'profile_name';
  static const String prefProfileEmail = 'profile_email';
  static const String prefNotifications = 'pref_notifications';
  static const String prefLocation = 'pref_location';
  static const String prefSound = 'pref_sound';
  static const String prefVibration = 'pref_vibration';
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefPinSetupDone = 'pref_pin_setup_done';
  static const String prefOnboardingDone = 'pref_onboarding_done';
  static const String prefLegalDisclaimerAccepted = 'pref_legal_disclaimer_accepted';
  static const String prefKvkkHealthConsentAccepted = 'pref_kvkk_health_consent_accepted';
  static const String prefTermsVersion = 'pref_terms_version';
  static const String prefRecordingWarningSeen = 'pref_recording_warning_shown';
  static const String prefNotificationPermissionPrompted =
      'pref_notification_permission_prompted';
  static const String prefDemoMode = 'pref_demo_mode';
  static const String prefVolumeTrigger = 'pref_volume_trigger';
  static const String prefShakeEnabled = 'pref_shake_enabled';
  static const String prefShakeSensitivity = 'pref_shake_sensitivity';
  static const String prefBloodType = 'profile_blood_type';
  static const String prefAllergies = 'profile_allergies';
  static const String prefMedicalConditions = 'profile_medical_conditions';
  static const String prefEmergencyNotes = 'profile_emergency_notes';
  static const String prefSmsTemplate = 'pref_sms_template';

  // Hukuki onay v1 (KVKK Kurul Kararı 2018/90 — aydınlatma + açık rıza ayrı kaydedilir)
  static const String prefLegalAcceptedV1 = 'legal_accepted_v1';
  static const String prefLegalTimestamp = 'legal_accepted_timestamp';
  static const String prefLegalAppVersion = 'legal_accepted_app_version';
  static const String prefAgeVerified = 'pref_age_verified';
  static const String prefContactConsentShown = 'pref_contact_consent_shown';

  // KVKK & Legal versiyon takibi
  static const String prefKvkkVersion = 'pref_kvkk_version';
  static const String prefFakeCallWarned = 'pref_fake_call_warned';

  // Rıza özellik durumu (ConsentManager ile senkronize edilir)
  static const String prefConsentLocation = 'pref_consent_location';
  static const String prefConsentBiometric = 'pref_consent_biometric';
  static const String prefConsentAudio = 'pref_consent_audio';
  static const String prefConsentEmergencyContacts =
      'pref_consent_emergency_contacts';
  static const String prefConsentProfile = 'pref_consent_profile';

  // Özellik bazlı ilk kullanım uyarı flag'leri (KVKK Md. 5 — işlemeden önce bildirim)
  static const String prefWarningPanic = 'warning_panic_shown';
  static const String prefWarningCheckin = 'warning_checkin_shown';
  static const String prefWarningWalk = 'warning_walk_shown';
  static const String prefWarningSiren = 'warning_siren_shown';

  // Yasal belgeler URL'leri
  static const String termsOfServiceUrl =
      'https://poyrazoncel34-netizen.github.io/guvenlik_app/kullanim_sartlari';
  static const String aydinlatmaMetniUrl =
      'https://poyrazoncel34-netizen.github.io/guvenlik_app/aydinlatma';
  static const String privacyPolicyWebUrl =
      'https://poyrazoncel34-netizen.github.io/guvenlik_app/';
  static const String privacyPolicyUrl =
      'https://poyrazoncel34-netizen.github.io/guvenlik_app/';
  static const String kvkkMailto =
      'mailto:korubeni.destek@gmail.com?subject=KVKK%20Ba%C5%9Fvurusu';
}
