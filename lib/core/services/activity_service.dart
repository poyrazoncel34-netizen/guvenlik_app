import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/activity_event.dart';
import '../di/service_locator.dart';
import 'local_database_service.dart';

class ActivityService {
  static const String _legacyStorageKey = 'activity_events';

  static Future<List<ActivityEvent>> getEvents() async {
    final db = await serviceLocator<LocalDatabaseService>().database;
    final rows = await db.query('activity_events', orderBy: 'timestamp DESC');
    if (rows.isEmpty) {
      await _migrateLegacyEvents();
      final migrated = await db.query(
        'activity_events',
        orderBy: 'timestamp DESC',
      );
      return migrated
          .map((row) => ActivityEvent.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }

    return rows
        .map((row) => ActivityEvent.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static Future<void> logEvent({
    required ActivityType type,
    required String title,
    required String description,
  }) async {
    final event = ActivityEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: title,
      description: description,
      timestamp: DateTime.now(),
    );

    final db = await serviceLocator<LocalDatabaseService>().database;
    await db.insert('activity_events', event.toMap());

    // Retention: keep only the most recent 1000 rows
    await db.rawDelete(
      'DELETE FROM activity_events WHERE id NOT IN '
      '(SELECT id FROM activity_events ORDER BY timestamp DESC LIMIT 1000)',
    );
  }

  static Future<void> clearAll() async {
    final db = await serviceLocator<LocalDatabaseService>().database;
    await db.delete('activity_events');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyStorageKey);
  }

  static Future<void> _migrateLegacyEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_legacyStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    final db = await serviceLocator<LocalDatabaseService>().database;
    for (final entry in raw) {
      try {
        final event = ActivityEvent.fromMap(
          jsonDecode(entry) as Map<String, dynamic>,
        );
        await db.insert(
          'activity_events',
          event.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {
        // Ignore malformed legacy rows.
      }
    }
  }
}
