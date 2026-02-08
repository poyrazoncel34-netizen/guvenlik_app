class AppConstants {
  static const String appName = 'KoruBeni';
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;
  static const String supportEmail = 'destek@korubeni.com';

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
  static const String prefDemoMode = 'pref_demo_mode';
}
