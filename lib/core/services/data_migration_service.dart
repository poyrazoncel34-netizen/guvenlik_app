import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Handles local data schema versioning.
/// When the app's data schema changes between versions,
/// this service applies necessary migrations automatically.
class DataMigrationService {
  static const String _versionKey = 'data_schema_version';
  static const int _currentVersion = 1;

  /// Run all pending migrations on app startup.
  static Future<void> migrate() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_versionKey) ?? 0;

    if (storedVersion >= _currentVersion) return;

    debugPrint('DataMigration: $storedVersion → $_currentVersion');

    for (int v = storedVersion + 1; v <= _currentVersion; v++) {
      await _applyMigration(v, prefs);
    }

    await prefs.setInt(_versionKey, _currentVersion);
    debugPrint('DataMigration: completed');
  }

  static Future<void> _applyMigration(
    int version,
    SharedPreferences prefs,
  ) async {
    switch (version) {
      case 1:
        // v1: Initial schema — no migration needed, just set the version.
        debugPrint('DataMigration: v1 — initial schema set');
        break;

      // Future migrations go here:
      // case 2:
      //   // Example: Rename a SharedPreferences key
      //   final oldValue = prefs.getString('old_key');
      //   if (oldValue != null) {
      //     await prefs.setString('new_key', oldValue);
      //     await prefs.remove('old_key');
      //   }
      //   break;

      default:
        debugPrint('DataMigration: unknown version $version, skipping');
    }
  }
}
