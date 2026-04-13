import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class AppSettingsService {
  AppSettingsService._();

  static Future<bool> notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefNotifications) ?? true;
  }

  static Future<bool> soundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefSound) ?? true;
  }
}
