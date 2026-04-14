import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../services/consent_manager.dart';
import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';
import 'contact_service.dart';
import 'local_database_service.dart';

class UserDataExportService {
  UserDataExportService._();

  static const String _offlineQueueKey = 'offline_event_queue';

  static Future<Map<String, dynamic>> buildExportData() async {
    final prefs = await SharedPreferences.getInstance();
    final secure = serviceLocator<SecureStorage>();
    final db = serviceLocator<LocalDatabaseService>();
    final consentManager = serviceLocator<ConsentManager>();

    final contacts = await ContactService.getContactRecords();
    final database = await db.database;
    final activityEvents = await database.query(
      'activity_events',
      orderBy: 'timestamp DESC',
      limit: 200,
    );
    final consentLogs = await db.getConsentLogs();

    return {
      'exportInfo': {
        'exportDate': DateTime.now().toIso8601String(),
        'appName': AppConstants.appName,
        'dataController': 'Poyraz Öncel — ${AppConstants.supportEmail}',
        'kvkkNote':
            'Bu dışa aktarım KVKK Madde 11/ğ kapsamında veri portabilitesi hakkı çerçevesinde oluşturulmuştur.',
      },
      'profile': await _profileData(prefs, secure),
      'emergencyContacts': contacts.map((contact) => contact.toJson()).toList(),
      'settings': {
        'notificationsEnabled':
            prefs.getBool(AppConstants.prefNotifications) ?? true,
        'soundEnabled': prefs.getBool(AppConstants.prefSound) ?? true,
        'volumeTriggerEnabled':
            prefs.getBool(AppConstants.prefVolumeTrigger) ?? false,
      },
      'fakeCall': await _fakeCallData(secure),
      'activityEvents': activityEvents,
      'offlineEvents': _offlineEvents(prefs),
      'consentLogs': consentLogs,
      'consentState': await consentManager.exportConsentLog(),
    };
  }

  static Future<Map<String, dynamic>> _fakeCallData(
    SecureStorage secure,
  ) async {
    final avatarPath = await secure.read(key: SecureStorageKeys.fakeCallAvatar);
    return {
      'callerName':
          await secure.read(key: SecureStorageKeys.fakeCallName) ?? '',
      'callerNumber':
          await secure.read(key: SecureStorageKeys.fakeCallNumber) ?? '',
      'hasAvatarFile': avatarPath != null && avatarPath.isNotEmpty,
      'avatarFileName': _fileName(avatarPath),
    };
  }

  static List<Map<String, dynamic>> _offlineEvents(SharedPreferences prefs) {
    final raw = prefs.getStringList(_offlineQueueKey) ?? const [];
    return raw
        .map((value) {
          try {
            final decoded = jsonDecode(value);
            if (decoded is Map) {
              return decoded.map((key, data) => MapEntry(key.toString(), data));
            }
          } catch (_) {}
          return <String, dynamic>{};
        })
        .where((event) => event.isNotEmpty)
        .toList(growable: false);
  }

  static String _fileName(String? path) {
    if (path == null || path.isEmpty) return '';
    return path.split('/').last;
  }

  static Future<Map<String, dynamic>> _profileData(
    SharedPreferences prefs,
    SecureStorage secure,
  ) async {
    final sensitive = await _sensitiveProfile(prefs, secure);
    return {
      'name': prefs.getString(AppConstants.prefProfileName) ?? '',
      'email': prefs.getString(AppConstants.prefProfileEmail) ?? '',
      ...sensitive,
    };
  }

  static Future<Map<String, String>> _sensitiveProfile(
    SharedPreferences prefs,
    SecureStorage secure,
  ) async {
    final raw = await secure.read(key: SecureStorageKeys.medicalProfile);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          );
        }
      } catch (_) {}
    }

    return {
      'bloodType': prefs.getString(AppConstants.prefBloodType) ?? '',
      'allergies': prefs.getString(AppConstants.prefAllergies) ?? '',
      'medicalConditions':
          prefs.getString(AppConstants.prefMedicalConditions) ?? '',
      'emergencyNotes': prefs.getString(AppConstants.prefEmergencyNotes) ?? '',
    };
  }
}
