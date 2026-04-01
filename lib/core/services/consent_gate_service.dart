// ============================================================================
// CONSENT GATE SERVICE — KVKK Rıza Kontrol Kapısı
// Tüm veri işleme operasyonlarından ÖNCE çağrılır.
// Rıza verilmemişse operasyonu engeller (KVKK m.5 uyumu).
// ============================================================================

import '../../models/consent_record.dart';
import '../../services/consent_manager.dart';
import '../di/service_locator.dart';

class ConsentGateService {
  ConsentGateService._();

  /// Konum verisi işleme için rıza kontrolü
  static bool isLocationAllowed() {
    return _isGranted(ConsentRecord.typeLocation);
  }

  /// Acil durum kişileri verisi işleme için rıza kontrolü
  static bool isEmergencyContactsAllowed() {
    return _isGranted(ConsentRecord.typeEmergencyContacts, defaultOnError: true);
  }

  /// Ses kaydı verisi işleme için rıza kontrolü
  static bool isAudioAllowed() {
    return _isGranted(ConsentRecord.typeAudio);
  }

  /// Sahte çağrı özelliği için rıza kontrolü
  static bool isFakeCallAllowed() {
    return _isGranted(ConsentRecord.typeFakeCall);
  }

  /// Profil verisi işleme için rıza kontrolü
  static bool isProfileAllowed() {
    return _isGranted(ConsentRecord.typeProfile);
  }

  /// Biyometrik veri işleme için rıza kontrolü
  static bool isBiometricAllowed() {
    return _isGranted(ConsentRecord.typeBiometric);
  }

  static bool _isGranted(String consentType, {bool defaultOnError = false}) {
    try {
      final cm = serviceLocator<ConsentManager>();
      return cm.isGranted(consentType);
    } catch (e) {
      // ConsentManager not yet initialized (cold-start race / init failure).
      // Emergency contacts fail-open; other consent types remain fail-closed.
      return defaultOnError;
    }
  }
}
