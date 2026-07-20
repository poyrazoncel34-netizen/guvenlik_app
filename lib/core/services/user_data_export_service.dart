import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../services/consent_manager.dart';
import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';
import 'contact_service.dart';
import 'emergency_platform_service.dart';
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
    return {
      'exportInfo': {
        'exportDate': DateTime.now().toIso8601String(),
        'appName': AppConstants.appName,
        'dataController':
            '${AppConstants.appName} — ${AppConstants.supportEmail}',
        'kvkkNote':
            'Bu dosya, KoruBeni uygulamasının bu cihazda erişebildiği '
            'verilerin kullanıcı tarafından başlatılan yerel bir kopyasıdır; '
            'veri sorumlusuna yapılan hukuki başvuru yerine geçmez.',
      },
      'profile': await _profileData(prefs),
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
      'nativeSafetyDiagnostics': await EmergencyPlatformService.instance
          .readNativeSafetyDiagnostics(),
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

  // Medical-profile data was removed from the export; only non-sensitive
  // identity fields remain in the user-controlled local data copy.
  static Future<Map<String, dynamic>> _profileData(
    SharedPreferences prefs,
  ) async {
    return {
      'name': prefs.getString(AppConstants.prefProfileName) ?? '',
      'email': prefs.getString(AppConstants.prefProfileEmail) ?? '',
    };
  }
}
