import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_environment.dart';
import '../di/service_locator.dart';
import 'local_database_service.dart';
import 'local_logger_service.dart';

class CrashLogService {
  CrashLogService._();

  static final CrashLogService instance = CrashLogService._();

  /// Cached so the crash path never waits on a platform channel twice. A crash
  /// record that cannot name its build is close to useless: with no telemetry,
  /// a user-submitted export is the ONLY post-incident evidence that exists
  /// (see docs/release/observability_and_slo.md).
  String? _cachedAppVersion;

  Future<String?> _appVersion() async {
    final cached = _cachedAppVersion;
    if (cached != null) return cached;
    try {
      final info = await PackageInfo.fromPlatform();
      final resolved = '${info.version}+${info.buildNumber}';
      _cachedAppVersion = resolved;
      return resolved;
    } on MissingPluginException {
      // Host-side tests have no platform channel; an unstamped row is still
      // worth recording.
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> record(LocalErrorCode code) async {
    try {
      final db = await serviceLocator<LocalDatabaseService>().database;
      await db.insert('crash_logs', {
        'source': 'runtime',
        'error': code.wireCode,
        'stack': null,
        'created_at': DateTime.now().toIso8601String(),
        'app_version': await _appVersion(),
        'environment': AppEnvironment.name,
      });
      await db.delete(
        'crash_logs',
        where:
            'id NOT IN (SELECT id FROM crash_logs ORDER BY created_at DESC LIMIT 100)',
      );
    } catch (_) {
      // Storage full or database unavailable: never interrupt emergency flow.
    }
  }

  Future<List<Map<String, Object?>>> listLogs() async {
    final db = await serviceLocator<LocalDatabaseService>().database;
    return db.query('crash_logs', orderBy: 'created_at DESC');
  }
}
