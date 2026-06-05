import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import 'emergency_platform_service.dart';
import 'local_database_service.dart';

class AppResetService {
  AppResetService._();

  static Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await serviceLocator<SecureStorage>().deleteAll();
    await serviceLocator<LocalDatabaseService>().deleteDatabaseFile();
    await _clearLocalFiles();
    // KVKK Md.7 (silme): also wipe the NATIVE korubeni_emergency prefs,
    // which hold the persisted primary contact number
    // (KEY_CHECK_IN_PRIMARY_NUMBER / KEY_COUNTDOWN_PRIMARY_NUMBER). Dart's
    // prefs.clear() only touches the Flutter-managed store, so without this
    // the number could survive a data deletion.
    await EmergencyPlatformService.instance.clearEmergencyPrefs();
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
