class AppConstants {
  static const String appName = 'KoruBeni';
  // Sürüm bilgisi artık package_info_plus ile alınıyor (PackageInfo.fromPlatform()).
  // Sabit appVersion/buildNumber kaldırıldı – tek kaynak pubspec.yaml.
  static const String supportEmail = 'korubeni.destek@gmail.com';

  /// Encryption key is loaded from dart-define at build time.
  /// Build with a redacted ENCRYPTION_KEY dart-define in release.
  /// Falls back to empty string — EncryptionService must handle gracefully.
  static String get encryptionKeyBase64 =>
      const String.fromEnvironment('ENCRYPTION_KEY', defaultValue: '');

  // PIN
  static const int pinLength = 4;
  static const int countdownSeconds = 10;

  // Limits
  static const int maxEmergencyContacts = 5;

  // SharedPreferences keys (non-sensitive)
  static const String prefProfileName = 'profile_name';
  static const String prefProfileEmail = 'profile_email';
  static const String prefNotifications = 'pref_notifications';
  static const String prefSound = 'pref_sound';
  static const String prefPinSetupDone = 'pref_pin_setup_done';
  static const String prefOnboardingDone = 'pref_onboarding_done';
  static const String prefLegalDisclaimerAccepted =
      'pref_legal_disclaimer_accepted';
  static const String prefTermsVersion = 'pref_terms_version';
  static const String prefNotificationPermissionPrompted =
      'pref_notification_permission_prompted';
  static const String prefDemoMode = 'pref_demo_mode';
  static const String prefVolumeTrigger = 'pref_volume_trigger';

  // One-time cleanup flag for the removed medical-profile feature (KVKK Md.7).
  static const String prefMedicalCleanupDone = 'pref_medical_cleanup_done';

  // Idempotency flag: emergency contacts have been migrated from the plaintext
  // sqflite `contacts` table (and older secure/prefs keys) into the canonical
  // keystore-backed secure store (KRİTİK-1 / H1). Only skips a legacy rescan;
  // the authority for "migration complete" is an empty `contacts` table.
  static const String prefContactsSecureMigratedV1 =
      'pref_contacts_secure_migrated_v1';

  // Legacy medical-profile keys — feature removed; retained only so the
  // one-time MedicalDataCleanupService can purge orphaned data on upgrade.
  // Delete next release once the cleanup has shipped to all users.
  @Deprecated(
    'removed in this release; kept only for one-time cleanup, delete next release',
  )
  static const String prefBloodType = 'profile_blood_type';
  @Deprecated(
    'removed in this release; kept only for one-time cleanup, delete next release',
  )
  static const String prefAllergies = 'profile_allergies';
  @Deprecated(
    'removed in this release; kept only for one-time cleanup, delete next release',
  )
  static const String prefMedicalConditions = 'profile_medical_conditions';
  @Deprecated(
    'removed in this release; kept only for one-time cleanup, delete next release',
  )
  static const String prefEmergencyNotes = 'profile_emergency_notes';
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
  static const String prefConsentEmergencyContacts =
      'pref_consent_emergency_contacts';
  static const String prefConsentProfile = 'pref_consent_profile';

  // Özellik bazlı ilk kullanım uyarı flag'leri (KVKK Md. 5 — işlemeden önce bildirim)
  static const String prefWarningPanic = 'warning_panic_shown';
  static const String prefWarningCheckin = 'warning_checkin_shown';
  static const String prefWarningWalk = 'warning_walk_shown';
  static const String prefWarningSiren = 'warning_siren_shown';
  static const String prefWarningLocation = 'warning_location_shown';

  // Yasal belgeler URL'leri
  static const String legalBaseUrl =
      'https://poyrazoncel34-netizen.github.io/guvenlik_app';
  static const String termsOfServiceUrl =
      '$legalBaseUrl/kullanim_sartlari.html';
  static const String subscriptionTermsUrl = termsOfServiceUrl;
  static const String aydinlatmaMetniUrl = '$legalBaseUrl/aydinlatma.html';
  static const String privacyPolicyWebUrl = '$legalBaseUrl/privacy_policy.html';
  static const String privacyPolicyUrl = '$legalBaseUrl/privacy_policy.html';
  static const String dataDeletionUrl = '$legalBaseUrl/data_deletion.html';
  static const String googlePlaySubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions?package=com.poyrazoncel.korubeni';
  static const String kvkkMailto =
      'mailto:korubeni.destek@gmail.com?subject=KVKK%20Ba%C5%9Fvurusu';
}
