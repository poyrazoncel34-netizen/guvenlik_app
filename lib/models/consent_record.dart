// ============================================================================
// KVKK RIZA KAYIT MODELİ
// Her rıza verildiğinde / geri çekildiğinde bir ConsentRecord oluşturulur.
// ============================================================================

class ConsentRecord {
  /// Rıza türü sabitlerini tutan iç sınıf
  static const String typeTerms = 'terms';
  static const String typeKvkk = 'kvkk';
  static const String typeLocation = 'location';
  static const String typeBiometric = 'biometric';
  static const String typeAudio = 'audio';
  static const String typeEmergencyContacts = 'emergency_contacts';
  static const String typeProfile = 'profile';
  static const String typeFakeCall = 'fake_call';
  static const String typeEmergencyContactPerson = 'emergency_contact_person';

  final String consentType;
  final bool granted;
  final DateTime timestamp;
  final String appVersion;
  final String osVersion;
  final String deviceModel;
  final String consentTextVersion;
  final String locale;

  const ConsentRecord({
    required this.consentType,
    required this.granted,
    required this.timestamp,
    required this.appVersion,
    required this.osVersion,
    required this.deviceModel,
    required this.consentTextVersion,
    required this.locale,
  });

  Map<String, dynamic> toJson() => {
        'consentType': consentType,
        'granted': granted,
        'timestamp': timestamp.toIso8601String(),
        'appVersion': appVersion,
        'osVersion': osVersion,
        'deviceModel': deviceModel,
        'consentTextVersion': consentTextVersion,
        'locale': locale,
      };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
        consentType: json['consentType'] as String,
        granted: json['granted'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
        appVersion: json['appVersion'] as String? ?? '',
        osVersion: json['osVersion'] as String? ?? '',
        deviceModel: json['deviceModel'] as String? ?? '',
        consentTextVersion: json['consentTextVersion'] as String? ?? '',
        locale: json['locale'] as String? ?? 'tr',
      );
}
