import '../di/service_locator.dart';
import 'local_database_service.dart';
import 'local_logger_service.dart';

class CrashLogService {
  CrashLogService._();

  static final CrashLogService instance = CrashLogService._();

  Future<void> record(LocalErrorCode code) async {
    try {
      final db = await serviceLocator<LocalDatabaseService>().database;
      await db.insert('crash_logs', {
        'source': 'runtime',
        'error': code.wireCode,
        'stack': null,
        'created_at': DateTime.now().toIso8601String(),
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
