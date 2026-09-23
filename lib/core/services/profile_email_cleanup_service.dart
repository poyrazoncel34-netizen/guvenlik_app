import 'package:shared_preferences/shared_preferences.dart';

/// Storage boundary for the legacy profile e-mail purge.
abstract interface class ProfileEmailCleanupStore {
  Future<bool> contains(String key);
  Future<bool> remove(String key);
}

class _PrefsProfileEmailCleanupStore implements ProfileEmailCleanupStore {
  const _PrefsProfileEmailCleanupStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<bool> contains(String key) async => _preferences.containsKey(key);

  @override
  Future<bool> remove(String key) => _preferences.remove(key);
}

/// Audit A-014 — deletes the profile e-mail that builds before 2026-04-16
/// stored under `profile_email`.
///
/// Later builds removed the field but kept the key, and the data export kept
/// emitting it. Nothing reads or writes an e-mail any more, so a value typed
/// into an old build would otherwise survive every update, unreadable and
/// unexportable, until a full data wipe.
///
/// Runs from the best-effort startup list, so it does not depend on the user
/// ever opening the profile or settings screen. There is deliberately no
/// completion flag: the check is one in-memory `containsKey`, and a failed
/// removal simply leaves the key for the next launch to retry.
class ProfileEmailCleanupService {
  ProfileEmailCleanupService._();

  /// The raw key old builds wrote.
  static const String legacyKey = 'profile_email';

  /// Returns true when the key is absent afterwards. Never throws.
  static Future<bool> purgeIfNeeded({ProfileEmailCleanupStore? store}) async {
    try {
      final cleanupStore =
          store ??
          _PrefsProfileEmailCleanupStore(await SharedPreferences.getInstance());
      if (!await cleanupStore.contains(legacyKey)) return true;
      return await cleanupStore.remove(legacyKey);
    } on Exception {
      // Idempotent: the key stays, the next launch retries.
      return false;
    }
  }
}
