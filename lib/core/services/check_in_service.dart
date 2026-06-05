// ============================================================================
// CHECK-IN / SAFE-WALK SERVİSİ (paylaşılan grace + dead-man's-switch)
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/activity_event.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../../screens/emergency_call_screen.dart';
import '../di/service_locator.dart';
import '../navigation/app_navigator.dart';
import '../services/activity_service.dart';
import '../services/call_service.dart';
import '../services/check_in_expiry_coordinator.dart';
import '../services/emergency_platform_service.dart';
import '../services/foreground_service.dart';
import '../services/haptic_service.dart';
import '../services/notification_service.dart';
import '../utils/emergency_number_validator.dart';

/// Shared session controller for the check-in / safe-walk dead-man's-switch.
///
/// One controller per [sessionId] (SPEC §3.1 / §6): both sessions run the SAME
/// phase machine (ACTIVE → 60s GRACE → ESCALATE) and the SAME grace UI. If the
/// user does not confirm safety within the set duration + grace period, ONLY the
/// primary emergency contact is called (no 112, no failover — SPEC §0 K1/K2).
class CheckInService extends ChangeNotifier {
  CheckInService._(this._sessionId);

  /// Check-in session controller (default).
  static final CheckInService instance = CheckInService._(
    CheckInExpiryCoordinator.checkInSession,
  );

  /// Safe-walk session controller — same machine, 60s grace (SPEC §6).
  static final CheckInService safeWalk = CheckInService._(
    CheckInExpiryCoordinator.safeWalkSession,
  );

  final String _sessionId;

  String get sessionId => _sessionId;
  bool get _isSafeWalk => _sessionId == CheckInExpiryCoordinator.safeWalkSession;

  static const int _gracePeriodSeconds = 60;

  // Per-session persistence key (safe-walk gets its own blob).
  String get _stateKey =>
      _isSafeWalk ? 'safe_walk_state_v2' : 'check_in_state_v2';

  // Per-session alert notification id (grace + emergency reuse the same id).
  int get _alertNotificationId => _isSafeWalk ? 9998 : 9999;

  // Legacy check-in keys for one-time migration (check-in session only).
  static const String _activeKey = 'check_in_active';
  static const String _totalSecondsKey = 'check_in_total_seconds';
  static const String _endAtKey = 'check_in_end_at';
  static const String _graceEndAtKey = 'check_in_grace_end_at';

  Timer? _tickTimer;
  DateTime? _endAt;
  DateTime? _graceEndAt;
  bool _isActive = false;
  bool _isGracePeriod = false;
  bool _emergencyInProgress = false;
  bool _nativeScheduleDegraded = false;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;

  bool get isActive => _isActive;
  bool get isGracePeriod => _isGracePeriod;
  bool get nativeScheduleDegraded => _nativeScheduleDegraded;
  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  DateTime? get endAt => _isGracePeriod ? _graceEndAt : _endAt;

  Future<void> initialize() async {
    await _restoreFromStorage();
  }

  Future<void> handleAppResumed() async {
    await _restoreFromStorage();
  }

  /// Start a session timer with [minutes] duration.
  Future<bool> start(int minutes) async {
    await stop();
    CheckInExpiryCoordinator.instance.arm(_sessionId);

    _totalSeconds = minutes * 60;
    _remainingSeconds = _totalSeconds;
    _isActive = true;
    _isGracePeriod = false;
    _endAt = DateTime.now().add(Duration(minutes: minutes));
    _graceEndAt = null;

    await _persistState();
    final nativeScheduled = await _scheduleNativeMainDeadline();
    _nativeScheduleDegraded = !nativeScheduled;
    await _startBackgroundProtection();
    _startMainTicker();

    await ActivityService.logEvent(
      type: _isSafeWalk ? ActivityType.locationShared : ActivityType.checkIn,
      title: (_isSafeWalk ? "safe_walk_started_activity" : "check_in_started_title")
          .tr(),
      description:
          (_isSafeWalk ? "safe_walk_started_desc" : "check_in_started_desc").tr(
        namedArgs: {'minutes': '$minutes'},
      ),
    );

    notifyListeners();
    return nativeScheduled;
  }

  /// User confirms they are safe — resets the timer (check-in semantics).
  Future<void> confirmSafe() async {
    if (!_isActive ||
        _totalSeconds <= 0 ||
        _emergencyInProgress ||
        CheckInExpiryCoordinator.instance.isClaimedFor(_sessionId)) {
      return;
    }
    CheckInExpiryCoordinator.instance.arm(_sessionId);

    _isGracePeriod = false;
    _graceEndAt = null;
    _endAt = DateTime.now().add(Duration(seconds: _totalSeconds));
    _remainingSeconds = _totalSeconds;

    await _persistState();
    final nativeScheduled = await _scheduleNativeMainDeadline();
    _nativeScheduleDegraded = !nativeScheduled;
    await _startBackgroundProtection();
    _startMainTicker();

    await ActivityService.logEvent(
      type: ActivityType.checkIn,
      title: "check_in_confirmed_title".tr(),
      description: "check_in_confirmed_desc".tr(),
    );

    notifyListeners();
  }

  /// Stop the session completely.
  Future<void> stop() async {
    _cancelTicker();
    _isActive = false;
    _isGracePeriod = false;
    _graceEndAt = null;
    _endAt = null;
    _remainingSeconds = 0;
    _totalSeconds = 0;
    _emergencyInProgress = false;
    _nativeScheduleDegraded = false;
    CheckInExpiryCoordinator.instance.reset(sessionId: _sessionId);

    await _clearPersistedState();
    await EmergencyPlatformService.instance.cancelCheckIn(
      sessionId: _sessionId,
    );
    await KoruBeniForegroundService.stop();
    notifyListeners();
  }

  Future<void> _restoreFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    // Try atomic JSON blob first
    final stateJson = prefs.getString(_stateKey);
    if (stateJson != null) {
      try {
        final state = jsonDecode(stateJson) as Map<String, dynamic>;
        final active = state['active'] as bool? ?? false;
        if (!active) return;

        final totalSeconds = state['totalSeconds'] as int? ?? 0;
        final restoredEndAt = _parseDateTime(state['endAt'] as String?);
        if (totalSeconds <= 0 || restoredEndAt == null) {
          await stop();
          return;
        }

        _isActive = true;
        _totalSeconds = totalSeconds;
        _endAt = restoredEndAt;
        _graceEndAt = _parseDateTime(state['graceEndAt'] as String?);

        await _reconcileWithClock();
        return;
      } catch (_) {
        // Corrupted JSON — fall through to legacy
      }
    }

    // Legacy key migration — check-in session only (safe-walk had no v1 blob).
    if (_isSafeWalk) return;

    final storedActive = prefs.getBool(_activeKey) ?? false;
    if (!storedActive) return;

    final totalSeconds = prefs.getInt(_totalSecondsKey) ?? 0;
    final restoredEndAt = _parseDateTime(prefs.getString(_endAtKey));
    if (totalSeconds <= 0 || restoredEndAt == null) {
      await stop();
      return;
    }

    _isActive = true;
    _totalSeconds = totalSeconds;
    _endAt = restoredEndAt;
    _graceEndAt = _parseDateTime(prefs.getString(_graceEndAtKey));

    // Migrate to atomic format
    await _persistState();
    await _clearLegacyKeys(prefs);

    await _reconcileWithClock();
  }

  Future<void> _reconcileWithClock() async {
    if (!_isActive || _endAt == null) {
      return;
    }

    final now = DateTime.now();
    if (_graceEndAt != null) {
      final graceRemaining = _graceEndAt!.difference(now).inSeconds;
      if (graceRemaining > 0) {
        _isGracePeriod = true;
        _remainingSeconds = graceRemaining;
        await _startBackgroundProtection();
        _startGraceTicker();
        notifyListeners();
        return;
      }

      await _triggerEmergency();
      return;
    }

    final mainRemaining = _endAt!.difference(now).inSeconds;
    if (mainRemaining > 0) {
      _isGracePeriod = false;
      _remainingSeconds = mainRemaining;
      await _startBackgroundProtection();
      _startMainTicker();
      notifyListeners();
      return;
    }

    _isGracePeriod = true;
    _graceEndAt = _endAt!.add(const Duration(seconds: _gracePeriodSeconds));
    await _persistState();

    final graceRemaining = _graceEndAt!.difference(now).inSeconds;
    if (graceRemaining > 0) {
      _remainingSeconds = graceRemaining;
      await _startBackgroundProtection();
      _startGraceTicker();
      notifyListeners();
      return;
    }

    await _triggerEmergency();
  }

  void _startMainTicker() {
    _cancelTicker();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final deadline = _endAt;
      if (!_isActive || deadline == null || _isGracePeriod) {
        _cancelTicker();
        return;
      }

      final remaining = deadline.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _onMainTimerExpired();
        return;
      }

      _remainingSeconds = remaining;
      notifyListeners();
    });
  }

  void _startGraceTicker() {
    _cancelTicker();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final deadline = _graceEndAt;
      if (!_isActive || deadline == null || !_isGracePeriod) {
        _cancelTicker();
        return;
      }

      final remaining = deadline.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _triggerEmergency();
        return;
      }

      _remainingSeconds = remaining;
      notifyListeners();
    });
  }

  Future<void> _onMainTimerExpired() async {
    if (!_isActive || _isGracePeriod) {
      return;
    }

    _cancelTicker();
    _isGracePeriod = true;
    _graceEndAt = DateTime.now().add(
      const Duration(seconds: _gracePeriodSeconds),
    );
    _remainingSeconds = _gracePeriodSeconds;

    await _persistState();
    final nativeScheduled = await _scheduleNativeGraceDeadline();
    _nativeScheduleDegraded = !nativeScheduled;
    await _startBackgroundProtection();
    await _showGraceNotification();
    _startGraceTicker();
    notifyListeners();
  }

  Future<void> _showGraceNotification() async {
    try {
      // NOTE (SPEC §0 K8 / §3.7): wording is the deferred text step. Both
      // sessions reuse the existing 60s-grace copy here; the lock-screen native
      // notification already carries session-correct wording.
      await NotificationService.instance.showEmergencyAlert(
        id: _alertNotificationId,
        title: "check_in_notification_title".tr(),
        body: "check_in_notification_body".tr(),
      );
    } catch (_) {
      // Notification not critical
    }
  }

  Future<void> _triggerEmergency() async {
    if (_emergencyInProgress) {
      return;
    }
    if (!CheckInExpiryCoordinator.instance.tryClaim(
      'check_in_service',
      sessionId: _sessionId,
    )) {
      return;
    }
    _emergencyInProgress = true;
    _cancelTicker();

    try {
      // Native-fired dedup: if the AlarmManager backup already called the
      // primary number (Dart frozen under Doze/app-kill), skip a second call.
      // Mirrors the countdown didCountdownAlarmFire guard (SPEC §3.2 / §5).
      final nativeAlreadyFired = await EmergencyPlatformService.instance
          .didCheckInAlarmFire(sessionId: _sessionId);
      if (nativeAlreadyFired) {
        await _clearMonitoringState(stopForeground: true);
        return;
      }

      // Cancel the native AlarmManager backup BEFORE any log / notification /
      // call, mirroring the proven countdown pattern (countdown_screen.dart
      // _makeEmergencyCall: "cancel native first, THEN dispatch"). This shrinks
      // the native-fired dedup window from the whole escalation body down to a
      // single cancel round-trip (SPEC §3.2 / §5). Cleanup-only: a failure here
      // must NEVER block the actual call (fail-safe) — cancelCheckIn already
      // swallows its own errors, and this guard mirrors countdown defensively.
      try {
        await EmergencyPlatformService.instance.cancelCheckIn(
          sessionId: _sessionId,
        );
      } on Exception catch (e) {
        debugPrint(
          'CheckInService: cancelCheckIn failed, continuing escalation: $e',
        );
      }

      await ActivityService.logEvent(
        type: ActivityType.emergencyTriggered,
        title: "check_in_emergency_title".tr(),
        description: "check_in_emergency_desc".tr(),
      );
      await HapticService.emergencyTriggered();
      await NotificationService.instance.showEmergencyAlert(
        id: _alertNotificationId,
        title: "check_in_emergency_title".tr(),
        body: "alarm_notification_body".tr(),
      );

      final contactsRepo = serviceLocator<ContactsRepository>();
      final primaryContact = await contactsRepo.getPrimaryEmergencyContact();
      final configuredNumbers = await contactsRepo.getAllEmergencyNumbers();

      // YALNIZ BIRINCIL KISI — tek hedef, failover yok, 112 yok (SPEC §0 K1/K2).
      final primaryNumber = resolvePrimaryNumber(
        primaryContactPhone: primaryContact?.phone,
        configuredNumbers: configuredNumbers,
      );
      var callResult = EmergencyCallResult.failed(primaryNumber);
      if (primaryNumber.isNotEmpty) {
        callResult = await CallService.startEmergencyCall(primaryNumber);
      }

      await _clearMonitoringState(stopForeground: !callResult.isSuccess);

      final navigator = rootNavigatorKey.currentState;
      if (navigator != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => EmergencyCallScreen(
              name: primaryContact?.name ?? "pin_verify_emergency_contact".tr(),
              phone: primaryNumber,
              callResult: callResult,
            ),
          ),
        );
      } else if (callResult.isSuccess) {
        await KoruBeniForegroundService.stop();
      }
    } catch (e) {
      debugPrint('CheckInService emergency trigger failed: $e');
      await _clearMonitoringState(stopForeground: true);
    } finally {
      _emergencyInProgress = false;
    }
  }

  /// Resolve the SINGLE primary escalation target (SPEC §0 Karar 1/2).
  /// Never synthesizes 112; returns empty when nothing callable is configured
  /// so the caller places NO call (requirement (b)).
  static String resolvePrimaryNumber({
    required String? primaryContactPhone,
    required List<String> configuredNumbers,
  }) {
    if (primaryContactPhone != null &&
        EmergencyNumberValidator.isCallableEmergencyTarget(
          primaryContactPhone,
        )) {
      return primaryContactPhone;
    }
    for (final number in configuredNumbers) {
      if (EmergencyNumberValidator.isCallableEmergencyTarget(number)) {
        return number;
      }
    }
    return '';
  }

  Future<String> _resolvePrimaryNumber() async {
    final contactsRepo = serviceLocator<ContactsRepository>();
    final primaryContact = await contactsRepo.getPrimaryEmergencyContact();
    final configuredNumbers = await contactsRepo.getAllEmergencyNumbers();
    return resolvePrimaryNumber(
      primaryContactPhone: primaryContact?.phone,
      configuredNumbers: configuredNumbers,
    );
  }

  Future<void> _startBackgroundProtection() async {
    await KoruBeniForegroundService.start();

    final String label;
    final String body;
    if (_isSafeWalk) {
      label = "foreground_active_title".tr();
      body = "foreground_safe_walk_status".tr(
        namedArgs: {'time': _formatDuration(_remainingSeconds)},
      );
    } else {
      label = _isGracePeriod
          ? "check_in_grace_label".tr()
          : "check_in_title".tr();
      body =
          '${"check_in_remaining".tr()}: ${_formatDuration(_remainingSeconds)}';
    }
    KoruBeniForegroundService.updateNotification(label, body);
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();

    if (!_isActive) {
      await _clearPersistedState();
      return;
    }

    final state = {
      'active': _isActive,
      'totalSeconds': _totalSeconds,
      'endAt': _endAt?.toIso8601String(),
      'graceEndAt': _graceEndAt?.toIso8601String(),
    };
    await prefs.setString(_stateKey, jsonEncode(state));
  }

  Future<void> _clearPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
    await _clearLegacyKeys(prefs);
  }

  Future<void> _clearLegacyKeys(SharedPreferences prefs) async {
    if (_isSafeWalk) return;
    await prefs.remove(_activeKey);
    await prefs.remove(_totalSecondsKey);
    await prefs.remove(_endAtKey);
    await prefs.remove(_graceEndAtKey);
  }

  Future<void> _clearMonitoringState({required bool stopForeground}) async {
    _cancelTicker();
    _isActive = false;
    _isGracePeriod = false;
    _graceEndAt = null;
    _endAt = null;
    _remainingSeconds = 0;
    _totalSeconds = 0;
    _nativeScheduleDegraded = false;

    await _clearPersistedState();
    await EmergencyPlatformService.instance.cancelCheckIn(
      sessionId: _sessionId,
    );
    if (stopForeground) {
      await KoruBeniForegroundService.stop();
    }
    notifyListeners();
  }

  Future<void> handleNativeGraceStarted() async {
    if (!_isActive) {
      return;
    }
    _cancelTicker();
    _isGracePeriod = true;
    _graceEndAt = DateTime.now().add(
      const Duration(seconds: _gracePeriodSeconds),
    );
    _remainingSeconds = _gracePeriodSeconds;
    await _persistState();
    final nativeScheduled = await _scheduleNativeGraceDeadline();
    _nativeScheduleDegraded = !nativeScheduled;
    await _showGraceNotification();
    _startGraceTicker();
    notifyListeners();
  }

  Future<void> handleNativeExpired() async {
    if (!_isActive) {
      return;
    }
    await _triggerEmergency();
  }

  Future<bool> _scheduleNativeMainDeadline() async {
    if (_endAt == null) {
      return false;
    }
    final primaryNumber = await _resolvePrimaryNumber();
    return EmergencyPlatformService.instance.scheduleCheckIn(
      sessionId: _sessionId,
      phase: 'main',
      deadline: _endAt!,
      graceDuration: const Duration(seconds: _gracePeriodSeconds),
      primaryNumber: primaryNumber,
    );
  }

  Future<bool> _scheduleNativeGraceDeadline() async {
    if (_graceEndAt == null) {
      return false;
    }
    final primaryNumber = await _resolvePrimaryNumber();
    return EmergencyPlatformService.instance.scheduleCheckIn(
      sessionId: _sessionId,
      phase: 'grace',
      deadline: _graceEndAt!,
      graceDuration: Duration.zero,
      primaryNumber: primaryNumber,
    );
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _cancelTicker() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
