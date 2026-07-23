import 'package:shared_preferences/shared_preferences.dart';

import '../../models/consent_record.dart';
import '../../services/consent_manager.dart';
import '../constants/app_constants.dart';
import 'check_in_service.dart';
import 'contact_service.dart';
import 'emergency_platform_service.dart';
import 'emergency_session_contract.dart';

/// Orders emergency-contact consent withdrawal across three authorities:
/// durable consent first (blocks new arm), native cancellation second, contact
/// deletion last. Unknown/too-late native state never becomes false success.
class EmergencyContactConsentWithdrawalService {
  EmergencyContactConsentWithdrawalService({
    ConsentManager? consentManager,
    EmergencyPlatformService? emergencyPlatform,
    Future<void> Function(String? locale)? revokeConsent,
    Future<WipeResult> Function()? wipeEmergencySessions,
    bool? platformSupported,
    Future<bool> Function()? clearSessionProjections,
    Future<void> Function()? deleteContacts,
    Future<bool> Function()? persistPreferenceWithdrawal,
  }) : _consentManager = consentManager,
       _emergencyPlatform = emergencyPlatform,
       _revokeConsent = revokeConsent,
       _wipeEmergencySessions = wipeEmergencySessions,
       _platformSupported = platformSupported,
       _clearSessionProjections =
           clearSessionProjections ?? _defaultClearSessionProjections,
       _deleteContacts = deleteContacts ?? ContactService.deleteAllContacts,
       _persistPreferenceWithdrawal =
           persistPreferenceWithdrawal ?? _defaultPersistPreferenceWithdrawal;

  final ConsentManager? _consentManager;
  final EmergencyPlatformService? _emergencyPlatform;
  final Future<void> Function(String? locale)? _revokeConsent;
  final Future<WipeResult> Function()? _wipeEmergencySessions;
  final bool? _platformSupported;
  final Future<bool> Function() _clearSessionProjections;
  final Future<void> Function() _deleteContacts;
  final Future<bool> Function() _persistPreferenceWithdrawal;

  Future<WipeResult> withdraw({String? locale}) async {
    try {
      // Publishing false first ensures a concurrent new-arm gate fails closed.
      final revokeConsent = _revokeConsent;
      if (revokeConsent != null) {
        await revokeConsent(locale);
      } else {
        final consentManager = _consentManager;
        if (consentManager == null) return WipeResult.unknown;
        await consentManager.revokeConsent(
          ConsentRecord.typeEmergencyContacts,
          locale: locale,
        );
      }
      if (!await _persistPreferenceWithdrawal()) return WipeResult.unknown;

      final platform = _emergencyPlatform;
      final platformSupported =
          _platformSupported ??
          (platform ?? EmergencyPlatformService.instance).isSupported;
      if (platformSupported) {
        final wipe = await (_wipeEmergencySessions != null
            ? _wipeEmergencySessions()
            : (platform ?? EmergencyPlatformService.instance)
                  .wipeEmergencySessions());
        if (wipe != WipeResult.completed) return wipe;
      }
      if (!await _clearSessionProjections()) return WipeResult.unknown;
      await _deleteContacts();
      return WipeResult.completed;
    } catch (_) {
      return WipeResult.unknown;
    }
  }

  static Future<bool> _defaultPersistPreferenceWithdrawal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(AppConstants.prefConsentEmergencyContacts, false);
  }

  static Future<bool> _defaultClearSessionProjections() async {
    final results = await Future.wait<bool>(<Future<bool>>[
      CheckInService.instance.clearAfterAuthoritativeNativeWipe(),
      CheckInService.safeWalk.clearAfterAuthoritativeNativeWipe(),
    ]);
    return results.every((result) => result);
  }
}
