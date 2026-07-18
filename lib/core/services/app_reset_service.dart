import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import 'emergency_platform_service.dart';
import 'emergency_session_contract.dart';
import 'contact_service.dart';
import 'local_database_service.dart';

class AppResetService {
  AppResetService._();

  /// Cancels and wipes native safety state before deleting credential/local
  /// data. An unacknowledged native wipe is not deletion success: callers must
  /// keep the user in a pending/recovery state and may retry reconciliation.
  static Future<WipeResult> clearLocalData({
    EmergencyPlatformService? emergencyPlatform,
  }) async {
    final platform = emergencyPlatform ?? EmergencyPlatformService.instance;
    if (platform.isSupported) {
      final wipeResult = await platform.wipeEmergencySessions();
      if (wipeResult != WipeResult.completed) return wipeResult;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await serviceLocator<SecureStorage>().deleteAll();
    await serviceLocator<LocalDatabaseService>().deleteDatabaseFile();
    // Drop the in-memory emergency-contact cache so a deleted contact is
    // never served again after KVKK "delete my data".
    ContactService.resetCache();
    await _clearLocalFiles();
    return WipeResult.completed;
  }

  static Future<void> _clearLocalFiles() async {
    final directories = <Directory>[];

    Future<void> addIfAvailable(Future<Directory> Function() loader) async {
      try {
        directories.add(await loader());
      } catch (_) {}
    }

    await addIfAvailable(getApplicationDocumentsDirectory);
    await addIfAvailable(getTemporaryDirectory);
    await addIfAvailable(getApplicationSupportDirectory);

    for (final directory in directories) {
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    }
  }
}
