import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Reports whether a long-running safety session (Check-In / Safe Walk) is
/// still persisted, without requiring the caller to hold a [SessionToken].
///
/// This exists for ONE caller: the pre-authentication lock screen. A local
/// data reset performed before the PIN is entered cancels every `PREPARING`
/// and `ARMED` native session and deletes the emergency contacts. Under the
/// duress model an attacker holding the device must not be able to do that,
/// so the reset is refused while a session projection exists.
///
/// The projection is deliberately the same SharedPreferences blob
/// `CheckInService` writes, so the probe cannot disagree with the running
/// session for a reason the user could not observe. A read failure is treated
/// as "a session may be active" (fail-closed): refusing a destructive reset is
/// recoverable (unlock, or reinstall), a wrongly cancelled safety session is
/// not.
class SafetySessionActivityProbe {
  const SafetySessionActivityProbe({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesLoader;

  static const SafetySessionActivityProbe instance =
      SafetySessionActivityProbe();

  /// Persistence keys owned by `CheckInService._stateKey`. Keep in sync: a
  /// renamed key must be added here, otherwise the guard silently stops
  /// protecting that session kind.
  static const List<String> sessionStateKeys = <String>[
    'check_in_state_v2',
    'safe_walk_state_v2',
  ];

  Future<bool> hasActiveSession() async {
    try {
      final preferences = await _preferencesLoader();
      for (final key in sessionStateKeys) {
        if (_isActiveState(preferences.getString(key))) return true;
      }
      return false;
    } on Exception {
      return true;
    }
  }

  bool _isActiveState(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return true;
      return decoded['active'] == true;
    } on FormatException {
      // An unparsable blob is not proof that nothing is armed.
      return true;
    }
  }
}
