import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';

/// Storage boundary for the one-time legacy medical-data purge.
abstract interface class MedicalDataCleanupStore {
  Future<bool> isCleanupDone();
  Future<bool> removePreference(String key);
  Future<void> deleteSecureMedicalProfile();
  Future<bool> publishCleanupDone();
}

class _DefaultMedicalDataCleanupStore implements MedicalDataCleanupStore {
  const _DefaultMedicalDataCleanupStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<bool> isCleanupDone() async {
    return _preferences.getBool(AppConstants.prefMedicalCleanupDone) ?? false;
  }

  @override
  Future<bool> removePreference(String key) => _preferences.remove(key);

  @override
  Future<void> deleteSecureMedicalProfile() {
    return serviceLocator<SecureStorage>().delete(
      // ignore: deprecated_member_use_from_same_package
      key: SecureStorageKeys.medicalProfile,
    );
  }

  @override
  Future<bool> publishCleanupDone() {
    return _preferences.setBool(AppConstants.prefMedicalCleanupDone, true);
  }
}

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

  static Future<void> purgeIfNeeded({MedicalDataCleanupStore? store}) async {
    final MedicalDataCleanupStore cleanupStore;
    try {
      cleanupStore =
          store ??
          _DefaultMedicalDataCleanupStore(
            await SharedPreferences.getInstance(),
          );
      if (await cleanupStore.isCleanupDone()) return;
    } catch (_) {
      debugPrint('MedicalDataCleanup: cleanup state unavailable');
      return;
    }

    var allDeleted = true;
    final legacyKeys = <String>[
      // ignore: deprecated_member_use_from_same_package
      AppConstants.prefBloodType,
      // ignore: deprecated_member_use_from_same_package
      AppConstants.prefAllergies,
      // ignore: deprecated_member_use_from_same_package
      AppConstants.prefMedicalConditions,
      // ignore: deprecated_member_use_from_same_package
      AppConstants.prefEmergencyNotes,
    ];

    // Attempt every independent legacy key so one rejected deletion does not
    // prevent the remaining sensitive data from being removed.
    for (final key in legacyKeys) {
      try {
        if (!await cleanupStore.removePreference(key)) allDeleted = false;
      } catch (_) {
        allDeleted = false;
      }
    }

    try {
      await cleanupStore.deleteSecureMedicalProfile();
    } catch (_) {
      allDeleted = false;
    }

    if (!allDeleted) {
      debugPrint('MedicalDataCleanup: purge incomplete; retry scheduled');
      return;
    }

    try {
      if (!await cleanupStore.publishCleanupDone()) {
        debugPrint('MedicalDataCleanup: completion marker not committed');
        return;
      }
    } catch (_) {
      debugPrint('MedicalDataCleanup: completion marker unavailable');
      return;
    }
    debugPrint('MedicalDataCleanup: purged legacy medical profile data');
  }
}
