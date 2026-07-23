// ============================================================================
// CONSENT GATE SERVICE — KVKK Rıza Kontrol Kapısı
// Bu servis yalnızca açıkça bağlanan akışlarda rıza durumunu okur.
// Zorunlu güvenlik akışları ayrı izin/onay adımlarıyla çalışır.
// ============================================================================

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/consent_record.dart';
import '../../services/consent_manager.dart';
import '../di/service_locator.dart';

class ConsentGateService {
  ConsentGateService._();

  /// Feature entry-point gate. Returns true when consent for [consentType] is
  /// granted; otherwise shows a localized SnackBar and returns false.
  ///
  /// Never call on the panic / SOS / countdown path — emergency calls must
  /// run regardless of consent state.
  static bool requireConsent(BuildContext context, String consentType) {
    final granted = _isGranted(consentType);
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('consent_gate_blocked'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return granted;
  }

  /// Konum verisi işleme için rıza kontrolü
  static bool isLocationAllowed() {
    return _isGranted(ConsentRecord.typeLocation);
  }

  /// Emergency-contact data processing gate. A missing/unreadable authority is
  /// not consent and therefore fails closed for every *new* safety arm. Native
  /// sessions that were already armed continue independently from Flutter.
  static bool isEmergencyContactsAllowed() {
    try {
      final cm = serviceLocator<ConsentManager>();
      return cm.isGranted(ConsentRecord.typeEmergencyContacts);
    } catch (_) {
      return false;
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
