import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';

/// KVKK Md.7 — one-time purge of legacy medical-profile data.
///
/// The medical-profile feature (blood type, allergies, conditions, emergency
/// notes) was removed. Users upgrading from a version that stored this special
/// category health data would otherwise leave it orphaned in secure storage and
/// legacy SharedPreferences. This service deletes it once and records a
/// completion flag so subsequent launches never touch secure storage again.
///
/// Idempotent and best-effort: any failure is swallowed so a cleanup error can
/// never block the emergency / notification startup path. The flag stays unset
/// on failure so a later launch can retry the purge.
class MedicalDataCleanupService {
  MedicalDataCleanupService._();

  static Future<void> purgeIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(AppConstants.prefMedicalCleanupDone) ?? false) {
        return;
      }

      // Legacy plaintext SharedPreferences keys (pre-secure-storage versions).
      // ignore: deprecated_member_use_from_same_package
      await prefs.remove(AppConstants.prefBloodType);
      // ignore: deprecated_member_use_from_same_package
      await prefs.remove(AppConstants.prefAllergies);
      // ignore: deprecated_member_use_from_same_package
      await prefs.remove(AppConstants.prefMedicalConditions);
      // ignore: deprecated_member_use_from_same_package
      await prefs.remove(AppConstants.prefEmergencyNotes);

      // Encrypted medical-profile blob (no-op if the key is absent).
      await serviceLocator<SecureStorage>().delete(
        // ignore: deprecated_member_use_from_same_package
        key: SecureStorageKeys.medicalProfile,
      );

      await prefs.setBool(AppConstants.prefMedicalCleanupDone, true);
      debugPrint('MedicalDataCleanup: purged legacy medical profile data');
    } catch (e) {
      // Best-effort: never block startup on cleanup failure.
      debugPrint('MedicalDataCleanup: skipped (\$e)');
    }
  }
}
