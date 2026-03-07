import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/shake_detector_service.dart';
import '../../core/services/volume_trigger_service.dart';

class SettingsProvider extends ChangeNotifier {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _volumeTriggerEnabled = false;
  bool _shakeEnabled = true;
  ShakeSensitivity _shakeSensitivity = ShakeSensitivity.medium;
  bool _loaded = false;

  String _profileName = '';
  String _profileEmail = '';
  String _bloodType = '';
  String _allergies = '';
  String _medicalConditions = '';
  String _emergencyNotes = '';

  bool get notificationsEnabled => _notificationsEnabled;
  bool get locationEnabled => _locationEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get volumeTriggerEnabled => _volumeTriggerEnabled;
  bool get shakeEnabled => _shakeEnabled;
  ShakeSensitivity get shakeSensitivity => _shakeSensitivity;
  String get profileName =>
      _profileName.isEmpty ? "settings_default_user".tr() : _profileName;
  String get profileEmail => _profileEmail.isEmpty ? '' : _profileEmail;
  String get bloodType => _bloodType;
  String get allergies => _allergies;
  String get medicalConditions => _medicalConditions;
  String get emergencyNotes => _emergencyNotes;
  bool get hasProfile => _profileName.isNotEmpty;

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _profileName = prefs.getString(AppConstants.prefProfileName) ?? '';
    _profileEmail = prefs.getString(AppConstants.prefProfileEmail) ?? '';
    _bloodType = prefs.getString(AppConstants.prefBloodType) ?? '';
    _allergies = prefs.getString(AppConstants.prefAllergies) ?? '';
    _medicalConditions =
        prefs.getString(AppConstants.prefMedicalConditions) ?? '';
    _emergencyNotes = prefs.getString(AppConstants.prefEmergencyNotes) ?? '';

    if (!_loaded) {
      _notificationsEnabled =
          prefs.getBool(AppConstants.prefNotifications) ?? true;
      _locationEnabled = prefs.getBool(AppConstants.prefLocation) ?? true;
      _soundEnabled = prefs.getBool(AppConstants.prefSound) ?? true;
      _vibrationEnabled = prefs.getBool(AppConstants.prefVibration) ?? true;
      _volumeTriggerEnabled =
          prefs.getBool(AppConstants.prefVolumeTrigger) ?? false;
      _shakeEnabled =
          prefs.getBool(AppConstants.prefShakeEnabled) ?? true;
      final shakeSenIdx =
          prefs.getInt(AppConstants.prefShakeSensitivity) ?? 1;
      _shakeSensitivity =
          ShakeSensitivity.values[shakeSenIdx.clamp(0, 2)];
      _loaded = true;
    }
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    String bloodType = '',
    String allergies = '',
    String medicalConditions = '',
    String emergencyNotes = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefProfileName, name.trim());
    await prefs.setString(AppConstants.prefProfileEmail, email.trim());
    await prefs.setString(AppConstants.prefBloodType, bloodType.trim());
    await prefs.setString(AppConstants.prefAllergies, allergies.trim());
    await prefs.setString(
      AppConstants.prefMedicalConditions,
      medicalConditions.trim(),
    );
    await prefs.setString(
      AppConstants.prefEmergencyNotes,
      emergencyNotes.trim(),
    );
    _profileName = name.trim();
    _profileEmail = email.trim();
    _bloodType = bloodType.trim();
    _allergies = allergies.trim();
    _medicalConditions = medicalConditions.trim();
    _emergencyNotes = emergencyNotes.trim();
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

  Future<void> setVolumeTrigger(bool value) async {
    _volumeTriggerEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefVolumeTrigger, value);
    await VolumeTriggerService.instance.setEnabled(value);
  }

  Future<void> setShakeEnabled(bool value) async {
    _shakeEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefShakeEnabled, value);
  }

  Future<void> setShakeSensitivity(ShakeSensitivity level) async {
    _shakeSensitivity = level;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefShakeSensitivity, level.index);
  }
}
