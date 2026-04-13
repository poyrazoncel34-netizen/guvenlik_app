// ============================================================================
// CONSENT GATE SERVICE — KVKK Rıza Kontrol Kapısı
// Bu servis yalnızca açıkça bağlanan akışlarda rıza durumunu okur.
// Zorunlu güvenlik akışları ayrı izin/onay adımlarıyla çalışır.
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
    try {
      final cm = serviceLocator<ConsentManager>();
      return cm.isGranted(ConsentRecord.typeEmergencyContacts);
    } catch (_) {
      // Emergency call flow must not be blocked by DI/bootstrap failure.
      return true;
    }
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

  static bool _isGranted(String consentType) {
    try {
      final cm = serviceLocator<ConsentManager>();
      return cm.isGranted(consentType);
    } catch (e) {
      // ConsentManager henüz initialize edilmemişse güvenli tarafta kal
      return false;
    }
  }
}
