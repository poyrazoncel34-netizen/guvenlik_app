import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'emergency_session_contract.dart';

/// The Dart-side PROJECTION of a check-in / safe-walk session.
///
/// This is a cache, never an authority: the native session slot owns the real
/// deadlines and the cancellable token (F01). The projection exists so the UI
/// can render a timer without a platform round-trip, so a missing, corrupt or
/// stale blob must degrade to "ask native", never to "there is no session".
///
/// Extracted from `CheckInService` so the controller keeps its phase machine
/// and this file keeps one concern: what is on disk and how it is migrated.
class CheckInProjectionStore {
  const CheckInProjectionStore({required this.isSafeWalk});

  final bool isSafeWalk;

  /// Per-session persistence key (safe-walk gets its own blob).
  String get stateKey => isSafeWalk ? 'safe_walk_state_v2' : 'check_in_state_v2';

  // Legacy check-in keys for one-time migration (check-in session only).
  static const String _activeKey = 'check_in_active';
  static const String _totalSecondsKey = 'check_in_total_seconds';
  static const String _endAtKey = 'check_in_end_at';
  static const String _graceEndAtKey = 'check_in_grace_end_at';

  /// Reads the stored token and duration, or null when nothing usable is on
  /// disk. A decode failure is reported as null rather than thrown: the caller
  /// must still go on to ask native, because a corrupt blob is NOT evidence
  /// that the session ended.
  Future<CheckInProjection?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(stateKey);
      if (raw == null) return null;
      final state = jsonDecode(raw) as Map<String, dynamic>;
      return CheckInProjection(
        token: SessionToken.fromMap(state['token']),
        totalSeconds: state['totalSeconds'] as int?,
      );
    } catch (_) {
      // Retain corrupt projections until a native answer is certain.
      return null;
    }
  }

  Future<void> write({
    required bool isActive,
    required int totalSeconds,
    required DateTime? endAt,
    required DateTime? graceEndAt,
    required SessionToken? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!isActive) {
      await clear();
      return;
    }
    await prefs.setString(stateKey, jsonEncode({
      'active': isActive,
      'totalSeconds': totalSeconds,
      'endAt': endAt?.toIso8601String(),
      'graceEndAt': graceEndAt?.toIso8601String(),
      'token': token?.toMap(),
    }));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(stateKey);
    await clearLegacyKeys(prefs);
  }

  /// Legacy active state has no versioned token and therefore cannot be a
  /// safety authority. Do not silently re-arm it with fresh commercial or
  /// contact decisions -- just remove it.
  Future<void> clearLegacyKeys(SharedPreferences prefs) async {
    if (isSafeWalk) return;
    await prefs.remove(_activeKey);
    await prefs.remove(_totalSecondsKey);
    await prefs.remove(_endAtKey);
    await prefs.remove(_graceEndAtKey);
  }
}

/// What the projection could tell us; both fields may be absent.
class CheckInProjection {
  const CheckInProjection({this.token, this.totalSeconds});

  final SessionToken? token;
  final int? totalSeconds;
}
