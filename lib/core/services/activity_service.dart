import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/activity_event.dart';
import '../di/service_locator.dart';
import 'local_database_service.dart';

class ActivityService {
  static const String _legacyStorageKey = 'activity_events';
  static const int _retentionLimit = 200;

  static Future<List<ActivityEvent>> getEvents() async {
    final db = await serviceLocator<LocalDatabaseService>().database;
    final rows = await db.query('activity_events', orderBy: 'timestamp DESC');
    if (rows.isEmpty) {
      await _migrateLegacyEvents();
      final migrated = await db.query(
        'activity_events',
        orderBy: 'timestamp DESC',
      );
      return _eventsFromRows(migrated);
    }

    return _eventsFromRows(rows);
  }

  static List<ActivityEvent> _eventsFromRows(List<Map<String, Object?>> rows) {
    final events = <ActivityEvent>[];
    for (final row in rows) {
      try {
        events.add(ActivityEvent.fromMap(Map<String, dynamic>.from(row)));
      } catch (_) {
        // Ignore malformed current database rows so one bad entry does not
        // crash the whole activity timeline.
      }
    }
    return List.unmodifiable(events);
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
    await db.rawDelete(
      '''
      DELETE FROM activity_events
      WHERE id NOT IN (
        SELECT id FROM activity_events
        ORDER BY timestamp DESC
        LIMIT ?
      )
      ''',
      [_retentionLimit],
    );
  }

  /// Deletes ONE recorded event.
  ///
  /// The Safety History merges user notes (SharedPreferences) with recorded
  /// events (sqflite). Its delete action only ever reached the notes, so
  /// "Sil" on a recorded event removed nothing and the row came straight back
  /// on reload. That contradicts both the app's own privacy policy (KVKK Md.
  /// 11/f is promised in legal_texts) and the regulation's definition of
  /// deletion: data must become "hicbir sekilde erisilemez ve tekrar
  /// kullanilamaz" (Silme Yonetmeligi Md. 8/1).
  static Future<void> deleteEvent(String id) async {
    if (id.isEmpty) return;
    final db = await serviceLocator<LocalDatabaseService>().database;
    await db.delete('activity_events', where: 'id = ?', whereArgs: [id]);
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
