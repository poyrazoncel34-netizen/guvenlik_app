import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/volume_trigger_service.dart';
import '../../core/services/app_reset_state_registry.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider() {
    AppResetStateRegistry.register(this, resetAfterDataDeletion);
  }

  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _volumeTriggerEnabled = false;
  bool _loaded = false;

  String _profileName = '';

  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get volumeTriggerEnabled => _volumeTriggerEnabled;
  String get profileName =>
      _profileName.isEmpty ? "settings_default_user".tr() : _profileName;
  bool get hasProfile => _profileName.isNotEmpty;

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _profileName = prefs.getString(AppConstants.prefProfileName) ?? '';

    if (!_loaded) {
      _notificationsEnabled =
          prefs.getBool(AppConstants.prefNotifications) ?? true;
      _soundEnabled = prefs.getBool(AppConstants.prefSound) ?? true;
      _volumeTriggerEnabled =
          prefs.getBool(AppConstants.prefVolumeTrigger) ?? false;
      _loaded = true;
    }
    notifyListeners();
  }

  Future<void> updateProfile({required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefProfileName, name.trim());
    _profileName = name.trim();
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefNotifications, value);
  }

  Future<void> setSound(bool value) async {
    _soundEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefSound, value);
  }

  Future<void> setVolumeTrigger(bool value) async {
    _volumeTriggerEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefVolumeTrigger, value);
    await VolumeTriggerService.instance.setEnabled(value);
  }

  Future<void> resetAfterDataDeletion() async {
    _notificationsEnabled = true;
    _soundEnabled = true;
    _volumeTriggerEnabled = false;
    _profileName = '';
    _loaded = false;
    await VolumeTriggerService.instance.setEnabled(false);
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    AppResetStateRegistry.unregister(this);
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
