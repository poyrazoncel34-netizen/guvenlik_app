import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/consent_manager.dart';
import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';
import 'contact_service.dart';
import 'database_integrity_service.dart';
import 'emergency_platform_service.dart';
import 'local_database_service.dart';
import 'local_logger_service.dart';

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
      'offlineEvents': await offlineEventsForExport(prefs),
      'nativeSafetyDiagnostics': await EmergencyPlatformService.instance
          .readNativeSafetyDiagnostics(),
      'consentState': await consentManager.exportConsentLog(),
      // The user-requested diagnostics stage of the MP-29-017 policy. This is
      // the one moment a FULL scan is right: the user asked, is watching, and
      // unbounded time is acceptable -- unlike the connection open path, where
      // the same scan grows with a table the user controls.
      'databaseIntegrity': (await DatabaseIntegrityService.scan(
        database,
        depth: IntegrityScanDepth.full,
      )).toMap(),
      'foreignKeyEnforcement':
          await DatabaseIntegrityService.foreignKeysEnabled(database),
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

  @visibleForTesting
  static Future<List<Map<String, dynamic>>> offlineEventsForExport(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getStringList(_offlineQueueKey) ?? const [];
    var unreadable = false;
    final events = raw
        .map((value) {
          try {
            final decoded = jsonDecode(value);
            if (decoded is Map) {
              return decoded.map((key, data) => MapEntry(key.toString(), data));
            }
            // Valid JSON but not an event object: dropped just the same, so
            // recorded just the same.
            unreadable = true;
          } on FormatException {
            unreadable = true;
          }
          return <String, dynamic>{};
        })
        .where((event) => event.isNotEmpty)
        .toList(growable: false);
    if (unreadable) {
      // Recorded once per export, as a code only: the raw entry can hold
      // event details and must not reach the diagnostics file.
      await LocalLoggerService.instance.warningCode(
        LocalWarningCode.exportOfflineEventUnreadable,
      );
    }
    return events;
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
    };
  }
}
