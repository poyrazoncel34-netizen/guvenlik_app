import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class SettingsProvider extends ChangeNotifier {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _loaded = false;

  String _profileName = '';
  String _profileEmail = '';

  bool get notificationsEnabled => _notificationsEnabled;
  bool get locationEnabled => _locationEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  String get profileName => _profileName.isEmpty ? 'Kullanıcı' : _profileName;
  String get profileEmail => _profileEmail.isEmpty ? '' : _profileEmail;
  bool get hasProfile => _profileName.isNotEmpty;

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _profileName = prefs.getString(AppConstants.prefProfileName) ?? '';
    _profileEmail = prefs.getString(AppConstants.prefProfileEmail) ?? '';

    if (!_loaded) {
      _notificationsEnabled =
          prefs.getBool(AppConstants.prefNotifications) ?? true;
      _locationEnabled = prefs.getBool(AppConstants.prefLocation) ?? true;
      _soundEnabled = prefs.getBool(AppConstants.prefSound) ?? true;
      _vibrationEnabled = prefs.getBool(AppConstants.prefVibration) ?? true;
      _loaded = true;
    }
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefProfileName, name.trim());
    await prefs.setString(AppConstants.prefProfileEmail, email.trim());
    _profileName = name.trim();
    _profileEmail = email.trim();
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefNotifications, value);
  }

  Future<void> setLocation(bool value) async {
    _locationEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefLocation, value);
  }

  Future<void> setSound(bool value) async {
    _soundEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefSound, value);
  }

  Future<void> setVibration(bool value) async {
    _vibrationEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefVibration, value);
  }
}
