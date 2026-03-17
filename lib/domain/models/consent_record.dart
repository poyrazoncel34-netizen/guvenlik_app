// ============================================================================
// CONSENT RECORD MODEL — KVKK rıza kayıt modeli
// ============================================================================

/// Rıza türleri — her biri ayrı bir KVKK rıza kalemi
enum ConsentType {
  termsOfService,
  kvkkDisclosure,
  locationData,
  biometricData,
  emergencyContacts,
  profileData,
  fakeCallAcknowledgment,
}

/// ConsentType ↔ String serialization
extension ConsentTypeExtension on ConsentType {
  String get key {
    switch (this) {
      case ConsentType.termsOfService:
        return 'terms_of_service';
      case ConsentType.kvkkDisclosure:
        return 'kvkk_disclosure';
      case ConsentType.locationData:
        return 'location_data';
      case ConsentType.biometricData:
        return 'biometric_data';
      case ConsentType.emergencyContacts:
        return 'emergency_contacts';
      case ConsentType.profileData:
        return 'profile_data';
      case ConsentType.fakeCallAcknowledgment:
        return 'fake_call_acknowledgment';
    }
  }

  static ConsentType fromKey(String key) {
    switch (key) {
      case 'terms_of_service':
        return ConsentType.termsOfService;
      case 'kvkk_disclosure':
        return ConsentType.kvkkDisclosure;
      case 'location_data':
        return ConsentType.locationData;
      case 'biometric_data':
        return ConsentType.biometricData;
      case 'emergency_contacts':
        return ConsentType.emergencyContacts;
      case 'profile_data':
        return ConsentType.profileData;
      case 'fake_call_acknowledgment':
        return ConsentType.fakeCallAcknowledgment;
      default:
        throw ArgumentError('Unknown ConsentType key: $key');
    }
  }
}

/// Tek bir rıza kaydı — KVKK loglama için
class ConsentRecord {
  final String id;
  final ConsentType type;
  final bool granted;
  final DateTime timestamp;
  final String appVersion;
  final String osVersion;
  final String deviceModel;
  final String consentTextVersion;
  final String locale;

  const ConsentRecord({
    required this.id,
    required this.type,
    required this.granted,
    required this.timestamp,
    required this.appVersion,
    required this.osVersion,
    required this.deviceModel,
    required this.consentTextVersion,
    required this.locale,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.key,
      'granted': granted ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'app_version': appVersion,
      'os_version': osVersion,
      'device_model': deviceModel,
      'consent_text_version': consentTextVersion,
      'locale': locale,
    };
  }

  factory ConsentRecord.fromMap(Map<String, dynamic> map) {
    return ConsentRecord(
      id: map['id'] as String,
      type: ConsentTypeExtension.fromKey(map['type'] as String),
      granted: (map['granted'] as int) == 1,
      timestamp: DateTime.parse(map['timestamp'] as String),
      appVersion: map['app_version'] as String,
      osVersion: map['os_version'] as String,
      deviceModel: map['device_model'] as String,
      consentTextVersion: map['consent_text_version'] as String,
      locale: map['locale'] as String,
    );
  }

  Map<String, dynamic> toJson() => toMap();
}
