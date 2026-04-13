import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/security/secure_storage.dart';
import '../../core/security/secure_storage_keys.dart';
import '../../core/services/volume_trigger_service.dart';

class SettingsProvider extends ChangeNotifier {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _volumeTriggerEnabled = false;
  bool _loaded = false;
  final SecureStorage _secureStorage = serviceLocator<SecureStorage>();

  String _profileName = '';
  String _profileEmail = '';
  String _bloodType = '';
  String _allergies = '';
  String _medicalConditions = '';
  String _emergencyNotes = '';

  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get volumeTriggerEnabled => _volumeTriggerEnabled;
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
    await _loadSensitiveProfile(prefs);

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
    await _saveSensitiveProfile(
      bloodType: bloodType.trim(),
      allergies: allergies.trim(),
      medicalConditions: medicalConditions.trim(),
      emergencyNotes: emergencyNotes.trim(),
    );
    _profileName = name.trim();
    _profileEmail = email.trim();
    _bloodType = bloodType.trim();
    _allergies = allergies.trim();
    _medicalConditions = medicalConditions.trim();
    _emergencyNotes = emergencyNotes.trim();
    notifyListeners();
  }

  Future<void> _loadSensitiveProfile(SharedPreferences prefs) async {
    final secureValue = await _secureStorage.read(
      key: SecureStorageKeys.medicalProfile,
    );
    if (secureValue != null && secureValue.isNotEmpty) {
      final decoded = _decodeSensitiveProfile(secureValue);
      _bloodType = decoded['bloodType'] ?? '';
      _allergies = decoded['allergies'] ?? '';
      _medicalConditions = decoded['medicalConditions'] ?? '';
      _emergencyNotes = decoded['emergencyNotes'] ?? '';
      return;
    }

    _bloodType = prefs.getString(AppConstants.prefBloodType) ?? '';
    _allergies = prefs.getString(AppConstants.prefAllergies) ?? '';
    _medicalConditions =
        prefs.getString(AppConstants.prefMedicalConditions) ?? '';
    _emergencyNotes = prefs.getString(AppConstants.prefEmergencyNotes) ?? '';

    final hasLegacySensitiveData =
        _bloodType.isNotEmpty ||
        _allergies.isNotEmpty ||
        _medicalConditions.isNotEmpty ||
        _emergencyNotes.isNotEmpty;
    if (!hasLegacySensitiveData) {
      return;
    }

    await _saveSensitiveProfile(
      bloodType: _bloodType,
      allergies: _allergies,
      medicalConditions: _medicalConditions,
      emergencyNotes: _emergencyNotes,
    );
  }

  Future<void> _saveSensitiveProfile({
    required String bloodType,
    required String allergies,
    required String medicalConditions,
    required String emergencyNotes,
  }) async {
    final payload = jsonEncode({
      'bloodType': bloodType,
      'allergies': allergies,
      'medicalConditions': medicalConditions,
      'emergencyNotes': emergencyNotes,
    });

    await _secureStorage.write(
      key: SecureStorageKeys.medicalProfile,
      value: payload,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefBloodType);
    await prefs.remove(AppConstants.prefAllergies);
    await prefs.remove(AppConstants.prefMedicalConditions);
    await prefs.remove(AppConstants.prefEmergencyNotes);
  }

  Map<String, String> _decodeSensitiveProfile(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const {};
      }

      return decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    } catch (_) {
      return const {};
    }
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
}
