// ============================================================================
// ONBOARDING CONTACT GATE SERVICE
// ============================================================================
// A safety app with no reachable contact is decor: with 112 removed from the
// dispatch target set, the countdown has nothing to call. Onboarding used to
// end after four informational pages and wrote prefOnboardingDone
// unconditionally, so a user could reach the home screen with zero contacts and
// only find out at the moment they pressed panic.
//
// This service owns the gate: whether onboarding MAY complete, and the write
// that completes it. Keeping both here (instead of in the screen) is what makes
// the "cannot skip" property testable without rendering a PageView.
//
// Source of truth is emergency_contacts_v1 through [ContactService]. The legacy
// database table stays empty and is not consulted.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/consent_record.dart';
import '../../services/consent_manager.dart';
import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../utils/emergency_number_validator.dart';
import 'contact_service.dart';

/// Result of persisting the onboarding contact.
enum OnboardingContactSaveOutcome {
  saved,

  /// The number is not a callable emergency target. Nothing was written.
  invalidPhone,

  /// The write was attempted but the contact is not readable afterwards.
  /// Treated as a failure so onboarding never reports success on a lost write.
  storageFailed,
}

abstract final class OnboardingContactGateService {
  /// True when a primary emergency contact exists AND its number is a callable
  /// target. A stored contact with an uncallable number does not satisfy the
  /// gate, because the countdown would reject it at arm time anyway
  /// (PanicArmPolicy 'callableTargetMissing').
  static Future<bool> hasCallableContact() async {
    try {
      final contact = await ContactService.getEmergencyContact();
      if (contact == null) return false;
      return EmergencyNumberValidator.isCallableEmergencyTarget(contact.phone);
    } on Exception catch (e) {
      // A storage fault must not be reported as "gate satisfied": failing
      // closed keeps the user on the step that fixes it.
      debugPrint('OnboardingContactGate: contact read failed: $e');
      return false;
    }
  }

  /// Display name of the stored primary contact, or null when there is none.
  /// Used only to confirm back to the user what was saved; never logged.
  static Future<String?> primaryContactName() async {
    try {
      final contact = await ContactService.getEmergencyContact();
      final name = contact?.name.trim();
      return (name == null || name.isEmpty) ? null : name;
    } on Exception catch (e) {
      debugPrint('OnboardingContactGate: contact name read failed: $e');
      return null;
    }
  }

  /// Translation key for an unusable number, or null when it is acceptable.
  /// Same rule the dispatch path applies, so the field cannot accept a number
  /// that arming would later refuse.
  static String? phoneErrorKey(String raw) {
    if (EmergencyNumberValidator.normalizedCallableTargetOrNull(raw) == null) {
      return 'onboarding_contact_invalid_phone';
    }
    return null;
  }

  /// True when KVKK consent for third-party contact data has not been granted.
  /// The consent is optional on the unified consent screen, so onboarding must
  /// be able to ask for it again instead of dead-ending on a declined toggle.
  static bool needsContactDataConsent() {
    return !_isEmergencyContactsConsentGranted();
  }

  /// Grants the emergency-contact data consent through the single consent path.
  /// Returns false when the consent log could not be written.
  static Future<bool> grantContactDataConsent({required String locale}) async {
    final manager = _consentManagerOrNull();
    if (manager == null) return false;
    try {
      await manager.grantConsent(
        ConsentRecord.typeEmergencyContacts,
        locale: locale,
      );
      return true;
    } on Exception catch (e) {
      debugPrint('OnboardingContactGate: consent grant failed: $e');
      return false;
    }
  }

  /// Persists [name]/[phone] as the primary emergency contact.
  ///
  /// The write is confirmed against storage, not against the absence of an
  /// exception: [ContactService.savePrimaryEmergencyContact] silently ignores
  /// unusable input, and its write path populates the warm in-memory cache
  /// without a read-back — so a keystore write that "succeeded" but never
  /// landed still reads back as present from the cache. Dropping the cache
  /// first forces the confirmation to come from secure storage.
  ///
  /// Dropping the cache is safe here: onboarding runs with no active safety
  /// session, and the next read re-hydrates it from the canonical store.
  static Future<OnboardingContactSaveOutcome> savePrimaryContact({
    required String name,
    required String phone,
  }) async {
    if (phoneErrorKey(phone) != null) {
      return OnboardingContactSaveOutcome.invalidPhone;
    }
    try {
      await ContactService.savePrimaryEmergencyContact(
        name: name,
        phone: phone,
      );
    } on Exception catch (e) {
      debugPrint('OnboardingContactGate: contact write failed: $e');
      return OnboardingContactSaveOutcome.storageFailed;
    }
    ContactService.resetCache();
    return await hasCallableContact()
        ? OnboardingContactSaveOutcome.saved
        : OnboardingContactSaveOutcome.storageFailed;
  }

  /// Writes prefOnboardingDone only when the gate is satisfied.
  ///
  /// Returns false without writing when no callable contact exists, so a caller
  /// that ignores the result still cannot leak an unconfigured install past
  /// onboarding.
  static Future<bool> completeOnboarding({SharedPreferences? prefs}) async {
    if (!await hasCallableContact()) return false;
    try {
      final store = prefs ?? await SharedPreferences.getInstance();
      return store.setBool(AppConstants.prefOnboardingDone, true);
    } on Exception catch (e) {
      debugPrint('OnboardingContactGate: completion write failed: $e');
      return false;
    }
  }

  static bool _isEmergencyContactsConsentGranted() {
    final manager = _consentManagerOrNull();
    // Before the consent manager is registered the honest answer is "not
    // granted yet", which shows the in-step consent request instead of writing
    // third-party data without a record.
    if (manager == null) return false;
    return manager.isGranted(ConsentRecord.typeEmergencyContacts);
  }

  /// Resolved without letting get_it throw: an unregistered ConsentManager is a
  /// bootstrap fault, and `serviceLocator<T>()` signals that with a StateError,
  /// which this app does not catch (Error subtypes stay uncaught by policy).
  static ConsentManager? _consentManagerOrNull() {
    if (!serviceLocator.isRegistered<ConsentManager>()) return null;
    return serviceLocator<ConsentManager>();
  }
}
