import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/activity_event.dart';

/// Lightweight local activity log.
/// Stores recent events in SharedPreferences (max 50 entries).
class ActivityService {
  static const String _storageKey = 'activity_events';
  static const int _maxEvents = 50;

  static Future<List<ActivityEvent>> getEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return raw
          .map(
            (e) => ActivityEvent.fromMap(jsonDecode(e) as Map<String, dynamic>),
          )
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      return [];
    }
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

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    raw.insert(0, jsonEncode(event.toMap()));
    if (raw.length > _maxEvents) {
      raw.removeRange(_maxEvents, raw.length);
    }
    await prefs.setStringList(_storageKey, raw);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
