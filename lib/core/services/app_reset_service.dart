import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import 'emergency_platform_service.dart';
import 'emergency_session_contract.dart';
import 'contact_service.dart';
import 'local_database_service.dart';

/// Local deletion boundary used by the app-reset transaction.
///
/// Every method must acknowledge its own storage boundary. A reset is only
/// reported as completed when all four boundaries acknowledge deletion.
abstract interface class AppResetLocalDataStore {
  Future<bool> clearPreferences();
  Future<void> clearSecureStorage();
  Future<void> deleteDatabase();
  Future<bool> clearLocalFiles();
}

class _DefaultAppResetLocalDataStore implements AppResetLocalDataStore {
  @override
  Future<bool> clearPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.clear();
  }

  @override
  Future<void> clearSecureStorage() {
    return serviceLocator<SecureStorage>().deleteAll();
  }

  @override
  Future<void> deleteDatabase() {
    return serviceLocator<LocalDatabaseService>().deleteDatabaseFile();
  }

  @override
  Future<bool> clearLocalFiles() => AppResetService._clearLocalFiles();
}

class AppResetService {
  AppResetService._();

  /// Cancels and wipes native safety state before deleting credential/local
  /// data. An unacknowledged native wipe is not deletion success: callers must
  /// keep the user in a pending/recovery state and may retry reconciliation.
  static Future<WipeResult> clearLocalData({
    EmergencyPlatformService? emergencyPlatform,
    AppResetLocalDataStore? localStore,
  }) async {
    final platform = emergencyPlatform ?? EmergencyPlatformService.instance;
    if (platform.isSupported) {
      final wipeResult = await platform.wipeEmergencySessions();
      if (wipeResult != WipeResult.completed) return wipeResult;
    }

    final store = localStore ?? _DefaultAppResetLocalDataStore();
    var allDeleted = true;

    // A partial wipe is still useful, so attempt every independent local
    // boundary. Never turn an exception or a rejected commit into success.
    try {
      if (!await store.clearPreferences()) allDeleted = false;
    } catch (_) {
      allDeleted = false;
    }

    var secureStorageDeleted = false;
    try {
      await store.clearSecureStorage();
      secureStorageDeleted = true;
    } catch (_) {
      allDeleted = false;
    }
    if (secureStorageDeleted) {
      // The emergency-contact cache mirrors secure storage. Invalidate it only
      // after that authority acknowledges deletion.
      ContactService.resetCache();
    }

    try {
      await store.deleteDatabase();
    } catch (_) {
      allDeleted = false;
    }

    try {
      if (!await store.clearLocalFiles()) allDeleted = false;
    } catch (_) {
      allDeleted = false;
    }

    return allDeleted ? WipeResult.completed : WipeResult.unknown;
  }

  static Future<bool> _clearLocalFiles() async {
    final directories = <Directory>[];
    var allDeleted = true;

    Future<void> addIfAvailable(Future<Directory> Function() loader) async {
      try {
        directories.add(await loader());
      } catch (_) {
        allDeleted = false;
      }
    }

    await addIfAvailable(getApplicationDocumentsDirectory);
    await addIfAvailable(getTemporaryDirectory);
    await addIfAvailable(getApplicationSupportDirectory);

    for (final directory in directories) {
      try {
        if (!await directory.exists()) continue;
        await for (final entity in directory.list(followLinks: false)) {
          await entity.delete(recursive: true);
        }
      } catch (_) {
        allDeleted = false;
      }
    }
    return allDeleted;
  }
}
