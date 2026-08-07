import 'package:shared_preferences/shared_preferences.dart';

/// Remembers when the user last completed a Test Mode rehearsal.
///
/// The readiness probe re-runs on every resume, so "last checked" always reads
/// as "just now" and tells the user nothing. The date that actually carries
/// information is the last time they watched the flow run end to end — that is
/// the only evidence their contact number and permissions still work.
///
/// Deliberately in plain [SharedPreferences]: this is not sensitive, it must
/// survive a keystore reset, and reading it must never block the home screen.
class RehearsalRecordService {
  RehearsalRecordService._();

  /// Stored as epoch milliseconds so the value survives locale/timezone edits.
  static const String prefLastRehearsalAt = 'last_rehearsal_at_v1';

  /// Called when a Test Mode countdown reaches the end. Never called from the
  /// real dispatch path — a real emergency is not a rehearsal.
  static Future<void> recordCompletedRehearsal({DateTime? at}) async {
    final prefs = await SharedPreferences.getInstance();
    final moment = at ?? DateTime.now();
    await prefs.setInt(prefLastRehearsalAt, moment.millisecondsSinceEpoch);
  }

  /// `null` means the user has never rehearsed — which is a fact worth showing,
  /// not an error state.
  static Future<DateTime?> lastRehearsalAt() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(prefLastRehearsalAt);
    if (stored == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(stored);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefLastRehearsalAt);
  }
}
