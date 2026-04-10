import '../di/service_locator.dart';
import 'local_database_service.dart';

class CrashLogService {
  CrashLogService._();

  static final CrashLogService instance = CrashLogService._();

  Future<void> record({
    required String source,
    required Object error,
    StackTrace? stackTrace,
  }) async {
    try {
      final db = await serviceLocator<LocalDatabaseService>().database;
      await db.insert('crash_logs', {
        'source': source,
        'error': error.toString(),
        'stack': stackTrace?.toString(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Storage full or database unavailable — swallow silently so the
      // emergency flow (call, siren) is never interrupted by a logging failure.
    }
  }

  Future<List<Map<String, Object?>>> listLogs() async {
    final db = await serviceLocator<LocalDatabaseService>().database;
    return db.query('crash_logs', orderBy: 'created_at DESC');
  }
}
