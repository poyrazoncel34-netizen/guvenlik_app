import 'package:shared_preferences/shared_preferences.dart';

import '../di/service_locator.dart';
import '../security/secure_storage.dart';

class AppResetService {
  AppResetService._();

  static Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await serviceLocator<SecureStorage>().deleteAll();
  }
}
