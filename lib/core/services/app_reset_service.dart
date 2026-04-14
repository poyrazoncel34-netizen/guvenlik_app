import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import 'local_database_service.dart';

class AppResetService {
  AppResetService._();

  static Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await serviceLocator<SecureStorage>().deleteAll();
    await serviceLocator<LocalDatabaseService>().deleteDatabaseFile();
    await _clearLocalFiles();
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
