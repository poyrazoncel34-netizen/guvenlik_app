class SecureStorageKeys {
  static const String userPin = 'user_pin';
  static const String fakeCallName = 'fake_call_name';
  static const String fakeCallNumber = 'fake_call_number';
  static const String fakeCallAvatar = 'fake_call_avatar';
  @Deprecated(
    'removed in this release; kept only for one-time cleanup, delete next release',
  )
  static const String medicalProfile = 'medical_profile';
  static const String contactsList = 'contacts_list';
  static const String contactsData = 'contacts_data';

  /// Canonical at-rest store for emergency contacts (KRİTİK-1 / H1). Single
  /// source of truth: a JSON envelope encrypted by the Android Keystore-backed
  /// flutter_secure_storage. Legacy keys above are read only during one-time
  /// migration and cleared afterwards.
  static const String emergencyContactsV1 = 'emergency_contacts_v1';
  static const String emergencyContactsList = 'emergency_contacts_list';
  static const String emergencyContactName = 'emergency_contact_name';
  static const String emergencyContactPhone = 'emergency_contact_phone';

  // KVKK Rıza Logları (ConsentManager tarafından kullanılır)
  static const String consentLog = 'kvkk_consent_log';
}
