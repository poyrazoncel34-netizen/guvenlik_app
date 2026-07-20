import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

abstract interface class MigrationPreferences {
  int? getInt(String key);

  Future<bool> setInt(String key, int value);

  Future<bool> setBool(String key, bool value);
}

class _SharedPreferencesMigrationPreferences implements MigrationPreferences {
  const _SharedPreferencesMigrationPreferences(this._preferences);

  final SharedPreferences _preferences;

  @override
  int? getInt(String key) => _preferences.getInt(key);

  @override
  Future<bool> setBool(String key, bool value) =>
      _preferences.setBool(key, value);

  @override
  Future<bool> setInt(String key, int value) => _preferences.setInt(key, value);
}

/// Handles local data schema versioning.
/// When the app's data schema changes between versions,
/// this service applies necessary migrations automatically.
class DataMigrationService {
  static const String _versionKey = 'data_schema_version';
  static const int _currentVersion = 2;

  /// Run all pending migrations on app startup.
  static Future<void> migrate({MigrationPreferences? store}) async {
    final prefs =
        store ??
        _SharedPreferencesMigrationPreferences(
          await SharedPreferences.getInstance(),
        );
    final storedVersion = prefs.getInt(_versionKey) ?? 0;

    if (storedVersion >= _currentVersion) return;

    debugPrint('DataMigration: $storedVersion → $_currentVersion');

    for (int v = storedVersion + 1; v <= _currentVersion; v++) {
      await _applyMigration(v, prefs);
    }

    final versionCommitted = await prefs.setInt(_versionKey, _currentVersion);
    if (!versionCommitted) {
      throw StateError('MIGRATION_VERSION_COMMIT_FAILED');
    }
    debugPrint('DataMigration: completed');
  }

  static Future<void> _applyMigration(
    int version,
    MigrationPreferences prefs,
  ) async {
    switch (version) {
      case 1:
        // v1: Initial schema — no migration needed, just set the version.
        debugPrint('DataMigration: v1 — initial schema set');
        break;

      case 2:
        // v2: Switched to EncryptedSharedPreferences on Android.
        // Existing secure storage data is unreadable after this change.
        // Reset PIN setup flag so the user re-enters their PIN once.
        final pinResetCommitted = await prefs.setBool(
          'pref_pin_setup_done',
          false,
        );
        if (!pinResetCommitted) {
          throw StateError('MIGRATION_PIN_RESET_COMMIT_FAILED');
        }
        debugPrint(
          'DataMigration: v2 — secure storage reset, PIN re-setup required',
        );
        break;

      default:
        debugPrint('DataMigration: unknown version $version, skipping');
    }
  }
}
