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
import '../services/consent_gate_service.dart';
import '../services/emergency_platform_service.dart';
import '../services/emergency_session_contract.dart';
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
  CheckInService._(
    this._sessionId, {
    EmergencyPlatformService? platform,
    ContactsRepository? contactsRepository,
    bool Function()? contactsConsentAllowed,
    bool sideEffectsEnabled = true,
  }) : _platform = platform ?? EmergencyPlatformService.instance,
       _contactsRepositoryOverride = contactsRepository,
       _contactsConsentAllowed =
           contactsConsentAllowed ??
           ConsentGateService.isEmergencyContactsAllowed,
       _sideEffectsEnabled = sideEffectsEnabled;

  factory CheckInService.forTesting({
    required String sessionId,
    required EmergencyPlatformService platform,
    required ContactsRepository contactsRepository,
    required bool Function() contactsConsentAllowed,
    bool sideEffectsEnabled = false,
  }) => CheckInService._(
    sessionId,
    platform: platform,
    contactsRepository: contactsRepository,
    contactsConsentAllowed: contactsConsentAllowed,
    sideEffectsEnabled: sideEffectsEnabled,
  );

  /// Check-in session controller (default).
  static final CheckInService instance = CheckInService._(
    CheckInExpiryCoordinator.checkInSession,
  );

  /// Safe-walk session controller — same machine, 60s grace (SPEC §6).
  static final CheckInService safeWalk = CheckInService._(
    CheckInExpiryCoordinator.safeWalkSession,
  );

  final String _sessionId;
  final EmergencyPlatformService _platform;
  final ContactsRepository? _contactsRepositoryOverride;
  final bool Function() _contactsConsentAllowed;
  final bool _sideEffectsEnabled;

  ContactsRepository get _contactsRepository =>
      _contactsRepositoryOverride ?? serviceLocator<ContactsRepository>();

  String get sessionId => _sessionId;
  String get _foregroundOwner => 'safety_session:$_sessionId';
  bool get _isSafeWalk =>
      _sessionId == CheckInExpiryCoordinator.safeWalkSession;

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
  bool _mutationInProgress = false;
  bool _reconciliationPending = false;
  bool _revisionDurationKnown = true;
  bool _nativeScheduleDegraded = false;
  Future<void>? _restoreInFlight;
  SessionToken? _sessionToken;
  String? _armedTarget;
  ArmResult? _lastArmResult;
  CancelResult? _lastCancelResult;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;

  bool get isActive => _isActive;
  bool get isGracePeriod => _isGracePeriod;
  bool get reconciliationPending => _reconciliationPending;
  bool get nativeScheduleDegraded => _nativeScheduleDegraded;
  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  DateTime? get endAt => _isGracePeriod ? _graceEndAt : _endAt;
  SessionToken? get sessionToken => _sessionToken;
  ArmResult? get lastArmResult => _lastArmResult;
  CancelResult? get lastCancelResult => _lastCancelResult;

  Future<void> initialize() => _restoreSerialized();

  Future<void> handleAppResumed() => _restoreSerialized();

  Future<void> _restoreSerialized() {
    final existing = _restoreInFlight;
    if (existing != null) return existing;
    final operation = _runRestore();
    _restoreInFlight = operation;
    return operation;
  }

  Future<void> _runRestore() async {
    try {
      await _restoreFromStorage();
    } finally {
      _restoreInFlight = null;
    }
  }

  /// Native-acknowledged arm. Dart becomes active only after [Armed].
  Future<ArmResult> startSession({
    required int minutes,
    required EntitlementDecision entitlementDecision,
    required bool pinConfigured,
  }) async {
    if (_restoreInFlight != null || _reconciliationPending) {
      return _lastArmResult = ArmRejected(
        'reconciliationPending',
        rejectedToken: _sessionToken,
      );
    }
    if (_mutationInProgress) {
      return _lastArmResult = ArmRejected(
        'operationInProgress',
        rejectedToken: _sessionToken,
      );
    }
    _mutationInProgress = true;
    try {
      return await _startSessionUnlocked(
        minutes: minutes,
        entitlementDecision: entitlementDecision,
        pinConfigured: pinConfigured,
      );
    } finally {
      _mutationInProgress = false;
    }
  }

  Future<ArmResult> _startSessionUnlocked({
    required int minutes,
    required EntitlementDecision entitlementDecision,
    required bool pinConfigured,
  }) async {
    if (_isActive || _sessionToken != null) {
      return _lastArmResult = ArmRejected(
        'sessionAlreadyActive',
        rejectedToken: _sessionToken,
      );
    }
    if (minutes <= 0) {
      return _lastArmResult = const ArmRejected('invalidDuration');
    }
    if (!_contactsConsentAllowed()) {
      return _lastArmResult = const ArmRejected('contactConsentRequired');
    }
    final target = await _resolvePrimaryNumber();
    if (target.isEmpty) {
      return _lastArmResult = const ArmRejected('callableTargetMissing');
    }

    final totalSeconds = minutes * 60;
    final mainDeadline = DateTime.now().add(Duration(seconds: totalSeconds));
    final finalDeadline = mainDeadline.add(
      const Duration(seconds: _gracePeriodSeconds),
    );
    final result = await _platform.armEmergencySession(
      kind: _isSafeWalk
          ? EmergencySessionKind.safeWalk
          : EmergencySessionKind.checkIn,
      mainDeadline: mainDeadline,
      finalDeadline: finalDeadline,
      target: target,
      entitlementDecision: entitlementDecision,
      pinConfigured: pinConfigured,
    );
    _lastArmResult = result;
    if (result is! Armed) return result;

    _sessionToken = result.sessionToken;
    _armedTarget = target;
    _totalSeconds = totalSeconds;
    _remainingSeconds = totalSeconds;
    _isActive = true;
    _isGracePeriod = false;
    _endAt = result.mainDeadline;
    _graceEndAt = result.finalDeadline;
    _nativeScheduleDegraded = false;
    _reconciliationPending = false;
    _revisionDurationKnown = true;

    // Native ARMED is authoritative. A projection write failure must not turn
    // a real armed session into a UI-level arm exception.
    await _bestEffort(_persistState);
    if (_sideEffectsEnabled) {
      await _bestEffort(_startBackgroundProtection);
      await _bestEffort(() async {
        await ActivityService.logEvent(
          type: _isSafeWalk
              ? ActivityType.locationShared
              : ActivityType.checkIn,
          title:
              (_isSafeWalk
                      ? "safe_walk_started_activity"
                      : "check_in_started_title")
                  .tr(),
          description:
              (_isSafeWalk ? "safe_walk_started_desc" : "check_in_started_desc")
                  .tr(namedArgs: {'minutes': '$minutes'}),
        );
      });
    }
    _startMainTicker();
    notifyListeners();
    return result;
  }

  /// Compatibility boundary. Unknown entitlement/PIN is intentionally denied;
  /// callers must migrate to [startSession] and pass verified decisions.
  @Deprecated('Use startSession and handle ArmResult explicitly.')
  Future<bool> start(int minutes) async => (await startSession(
    minutes: minutes,
    entitlementDecision: EntitlementDecision.unknown,
    pinConfigured: false,
  )).isArmed;

  /// Atomically revises the native generation; old alarms become stale.
  Future<ArmResult> confirmSafeSession() async {
    if (_restoreInFlight != null || _reconciliationPending) {
      return _lastArmResult = ArmRejected(
        'reconciliationPending',
        rejectedToken: _sessionToken,
      );
    }
    if (_mutationInProgress) {
      return _lastArmResult = ArmRejected(
        'operationInProgress',
        rejectedToken: _sessionToken,
      );
    }
    _mutationInProgress = true;
    try {
      return await _confirmSafeSessionUnlocked();
    } finally {
      _mutationInProgress = false;
    }
  }

  Future<ArmResult> _confirmSafeSessionUnlocked() async {
    final token = _sessionToken;
    final target = _armedTarget;
    if (!_isActive ||
        token == null ||
        target == null ||
        _totalSeconds <= 0 ||
        !_revisionDurationKnown ||
        _emergencyInProgress) {
      return _lastArmResult = ArmRejected(
        'noRevisableSession',
        rejectedToken: token,
      );
    }

    final mainDeadline = DateTime.now().add(Duration(seconds: _totalSeconds));
    final finalDeadline = mainDeadline.add(
      const Duration(seconds: _gracePeriodSeconds),
    );
    final result = await _platform.reviseEmergencySession(
      token: token,
      mainDeadline: mainDeadline,
      finalDeadline: finalDeadline,
      targetSnapshot: target,
    );
    _lastArmResult = result;
    if (result is! Armed) return result;

    _sessionToken = result.sessionToken;
    _isGracePeriod = false;
    _endAt = result.mainDeadline;
    _graceEndAt = result.finalDeadline;
    _remainingSeconds = _totalSeconds;
    await _bestEffort(_persistState);
    if (_sideEffectsEnabled) {
      await _bestEffort(_startBackgroundProtection);
      await _bestEffort(() async {
        await ActivityService.logEvent(
          type: ActivityType.checkIn,
          title: "check_in_confirmed_title".tr(),
          description: "check_in_confirmed_desc".tr(),
        );
      });
    }
    _startMainTicker();
    notifyListeners();
    return result;
  }

  @Deprecated('Use confirmSafeSession and handle ArmResult explicitly.')
  Future<ArmResult> confirmSafe() => confirmSafeSession();

  /// Native tombstone acknowledgement is required before local state clears.
  Future<CancelResult?> stopSession() async {
    final token = _sessionToken;
    if (token == null) return null;
    if (_mutationInProgress) {
      return _lastCancelResult = SessionCancelUnknown(
        token,
        'operationInProgress',
      );
    }
    _mutationInProgress = true;
    try {
      return await _stopSessionUnlocked(token);
    } finally {
      _mutationInProgress = false;
    }
  }

  Future<CancelResult> _stopSessionUnlocked(SessionToken token) async {
    _cancelTicker();
    final result = await _platform.cancelEmergencySession(token);
    _lastCancelResult = result;
    if (!result.isConfirmedCancelled) {
      _startTickerForCurrentPhase();
      notifyListeners();
      return result;
    }

    await _clearLocalProjection(stopForeground: true);
    return result;
  }

  @Deprecated('Use stopSession and handle CancelResult explicitly.')
  Future<CancelResult?> stop() => stopSession();

  Future<void> _restoreFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final stateJson = prefs.getString(_stateKey);
    if (stateJson == null) {
      // Legacy active state has no versioned token and therefore cannot be a
      // safety authority. Do not silently re-arm it with fresh commercial or
      // contact decisions.
      await _clearLegacyKeys(prefs);
      await _restoreDiscoveredNativeSession();
      return;
    }

    Map<String, dynamic> state;
    try {
      final decoded = jsonDecode(stateJson);
      if (decoded is! Map) throw const FormatException('projectionNotMap');
      state = decoded.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    } catch (_) {
      // Never erase the only clue that a native authority may exist until a
      // typed native read proves absence.
      await _restoreDiscoveredNativeSession();
      return;
    }

    final token = SessionToken.fromMap(state['token']);
    final totalSeconds = wireInt(state['totalSeconds']) ?? 0;
    if (token == null || totalSeconds <= 0 || token.kind != _sessionKind) {
      await _restoreDiscoveredNativeSession();
      return;
    }

    final snapshot = await _platform.readEmergencySession(token);
    if (snapshot.status == SessionReadStatus.absent) {
      await _clearLocalProjection(stopForeground: true);
      return;
    }
    if (snapshot.status == SessionReadStatus.unknown ||
        snapshot.status == SessionReadStatus.corrupted) {
      await _preserveUncertainProjection(
        state: state,
        token: token,
        totalSeconds: totalSeconds,
      );
      return;
    }
    if (snapshot.lifecycleState == EmergencySessionLifecycle.cancelled ||
        snapshot.lifecycleState.isTerminal) {
      await _clearLocalProjection(stopForeground: true);
      return;
    }
    if (snapshot.lifecycleState != EmergencySessionLifecycle.armed) {
      // CLAIMED/PREPARING remains visible as an unresolved native authority,
      // but is not projected as a running timer.
      _sessionToken = snapshot.token ?? token;
      _emergencyInProgress =
          snapshot.lifecycleState == EmergencySessionLifecycle.claimed;
      _reconciliationPending = true;
      _isActive = false;
      _cancelTicker();
      notifyListeners();
      return;
    }

    await _projectArmedSnapshot(
      snapshot,
      totalSeconds: totalSeconds,
      revisionDurationKnown: state['revisionDurationKnown'] != false,
    );
  }

  EmergencySessionKind get _sessionKind => _isSafeWalk
      ? EmergencySessionKind.safeWalk
      : EmergencySessionKind.checkIn;

  Future<void> _restoreDiscoveredNativeSession() async {
    final snapshot = await _platform.discoverEmergencySession(_sessionKind);
    if (snapshot.status == SessionReadStatus.absent) {
      _reconciliationPending = false;
      await _clearPersistedState();
      return;
    }
    if (snapshot.status == SessionReadStatus.unknown ||
        snapshot.status == SessionReadStatus.corrupted) {
      _reconciliationPending = true;
      _cancelTicker();
      notifyListeners();
      return;
    }
    if (snapshot.lifecycleState == EmergencySessionLifecycle.cancelled ||
        snapshot.lifecycleState.isTerminal) {
      await _clearLocalProjection(stopForeground: true);
      return;
    }
    if (snapshot.lifecycleState != EmergencySessionLifecycle.armed) {
      _sessionToken = snapshot.token;
      _emergencyInProgress =
          snapshot.lifecycleState == EmergencySessionLifecycle.claimed;
      _reconciliationPending = true;
      _isActive = false;
      _cancelTicker();
      notifyListeners();
      return;
    }

    final mainDeadline = snapshot.mainDeadline;
    if (mainDeadline == null) {
      _reconciliationPending = true;
      return;
    }
    final conservativeDuration = mainDeadline
        .difference(DateTime.now())
        .inSeconds
        .clamp(1, 24 * 60 * 60)
        .toInt();
    await _projectArmedSnapshot(
      snapshot,
      totalSeconds: conservativeDuration,
      revisionDurationKnown: false,
    );
    await _bestEffort(_persistState);
  }

  Future<void> _projectArmedSnapshot(
    SessionSnapshot snapshot, {
    required int totalSeconds,
    required bool revisionDurationKnown,
  }) async {
    final token = snapshot.token;
    final mainDeadline = snapshot.mainDeadline;
    final finalDeadline = snapshot.finalDeadline;
    final target = snapshot.target;
    if (token == null ||
        token.kind != _sessionKind ||
        mainDeadline == null ||
        finalDeadline == null ||
        target == null ||
        target.isEmpty) {
      _reconciliationPending = true;
      _cancelTicker();
      notifyListeners();
      return;
    }
    _sessionToken = token;
    _armedTarget = target;
    _totalSeconds = totalSeconds;
    _isActive = true;
    _endAt = mainDeadline;
    _graceEndAt = finalDeadline;
    _reconciliationPending = false;
    _revisionDurationKnown = revisionDurationKnown;
    await _reconcileWithClock();
  }

  Future<void> _preserveUncertainProjection({
    required Map<String, dynamic> state,
    required SessionToken token,
    required int totalSeconds,
  }) async {
    _sessionToken = token;
    _totalSeconds = totalSeconds;
    _revisionDurationKnown = state['revisionDurationKnown'] != false;
    _reconciliationPending = true;
    _endAt = DateTime.tryParse(state['endAt']?.toString() ?? '');
    _graceEndAt = DateTime.tryParse(state['graceEndAt']?.toString() ?? '');
    _isActive =
        _endAt != null &&
        _graceEndAt != null &&
        !_graceEndAt!.isBefore(_endAt!);
    if (_isActive) {
      await _reconcileWithClock();
    } else {
      _cancelTicker();
      notifyListeners();
    }
  }

  Future<void> _reconcileWithClock() async {
    if (!_isActive || _endAt == null || _graceEndAt == null) {
      return;
    }

    final now = DateTime.now();
    final mainRemaining = _endAt!.difference(now).inSeconds;
    if (mainRemaining > 0) {
      _isGracePeriod = false;
      _remainingSeconds = mainRemaining;
      if (_sideEffectsEnabled) {
        await _bestEffort(_startBackgroundProtection);
      }
      _startMainTicker();
      notifyListeners();
      return;
    }

    _isGracePeriod = true;
    final graceRemaining = _graceEndAt!.difference(now).inSeconds;
    if (graceRemaining > 0) {
      _remainingSeconds = graceRemaining;
      if (_sideEffectsEnabled) {
        await _bestEffort(_startBackgroundProtection);
      }
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
    final finalDeadline = _graceEndAt;
    if (finalDeadline == null) {
      await _triggerEmergency();
      return;
    }
    _remainingSeconds = finalDeadline
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, _gracePeriodSeconds)
        .toInt();

    await _persistState();
    if (_sideEffectsEnabled) {
      await _bestEffort(_startBackgroundProtection);
      await _bestEffort(_showGraceNotification);
    }
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
    if (_emergencyInProgress) return;
    final token = _sessionToken;
    if (token == null) return;
    _emergencyInProgress = true;
    _cancelTicker();

    try {
      // This is the first external/safety-relevant side effect. Native owns
      // claim, fallback post and Telecom request; DB/log/haptic/navigation can
      // fail afterwards without turning the event into a zero-dispatch path.
      final dispatch = await _platform.dispatchEmergencySession(
        token: token,
        source: 'dartCheckInExpiry',
      );
      if (dispatch.isUnknown) {
        // Unknown is neither success nor failure. Keep native/Dart projection
        // intact for same-token reconciliation and never show a false terminal
        // state.
        return;
      }
      if (dispatch.wasCancelled) {
        await _clearLocalProjection(stopForeground: true);
        return;
      }

      final primaryNumber = _armedTarget ?? '';
      final callResult = dispatch.requestWasSubmitted
          ? EmergencyCallResult.requested(primaryNumber)
          : EmergencyCallResult.failed(primaryNumber);

      await _clearLocalProjection(stopForeground: !callResult.isSuccess);

      if (_sideEffectsEnabled) {
        await _bestEffort(() async {
          await ActivityService.logEvent(
            type: ActivityType.emergencyTriggered,
            title: "check_in_emergency_title".tr(),
            description: "check_in_emergency_desc".tr(),
          );
        });
        await _bestEffort(HapticService.emergencyTriggered);
        await _bestEffort(() async {
          await NotificationService.instance.showEmergencyAlert(
            id: _alertNotificationId,
            title: "check_in_emergency_title".tr(),
            body: "alarm_notification_body".tr(),
          );
        });
      }

      final navigator = rootNavigatorKey.currentState;
      if (navigator != null) {
        await _bestEffort(() async {
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => EmergencyCallScreen(
                name: "pin_verify_emergency_contact".tr(),
                phone: primaryNumber,
                callResult: callResult,
                foregroundOwner: _foregroundOwner,
              ),
            ),
          );
        });
      } else if (callResult.isSuccess && _sideEffectsEnabled) {
        await _bestEffort(
          () => KoruBeniForegroundService.stop(owner: _foregroundOwner),
        );
      }
    } catch (_) {
      debugPrint('CheckInService emergency trigger failed');
    } finally {
      _emergencyInProgress = false;
    }
  }

  /// Resolve the SINGLE primary escalation target (SPEC §0 Karar 1/2).
  /// Never synthesizes 112; returns empty when nothing callable is configured
  /// so the caller places NO call (requirement (b)).
  static String resolvePrimaryNumber({required String? primaryContactPhone}) {
    if (primaryContactPhone != null &&
        EmergencyNumberValidator.isCallableEmergencyTarget(
          primaryContactPhone,
        )) {
      return primaryContactPhone;
    }
    return '';
  }

  Future<String> _resolvePrimaryNumber() async {
    final primaryContact = await _contactsRepository
        .getPrimaryEmergencyContact();
    return resolvePrimaryNumber(primaryContactPhone: primaryContact?.phone);
  }

  Future<void> _startBackgroundProtection() async {
    await KoruBeniForegroundService.start(owner: _foregroundOwner);

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
    KoruBeniForegroundService.updateNotification(
      owner: _foregroundOwner,
      title: label,
      content: body,
    );
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
      'token': _sessionToken?.toMap(),
      'revisionDurationKnown': _revisionDurationKnown,
    };
    if (!await prefs.setString(_stateKey, jsonEncode(state))) {
      throw StateError('checkInProjectionWriteFailed');
    }
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

  Future<void> _clearLocalProjection({required bool stopForeground}) async {
    _cancelTicker();
    _isActive = false;
    _isGracePeriod = false;
    _graceEndAt = null;
    _endAt = null;
    _remainingSeconds = 0;
    _totalSeconds = 0;
    _nativeScheduleDegraded = false;
    _reconciliationPending = false;
    _revisionDurationKnown = true;
    _sessionToken = null;
    _armedTarget = null;

    await _bestEffort(_clearPersistedState);
    if (stopForeground && _sideEffectsEnabled) {
      await _bestEffort(
        () => KoruBeniForegroundService.stop(owner: _foregroundOwner),
      );
    }
    notifyListeners();
  }

  /// Clears the Dart projection only after the native coordinator has already
  /// returned WipeResult.completed. Unlike normal best-effort UI cleanup, this
  /// boundary verifies that the persisted target/token projection is absent so
  /// consent withdrawal cannot report completion while retaining contact PII.
  Future<bool> clearAfterAuthoritativeNativeWipe() async {
    _cancelTicker();
    _isActive = false;
    _isGracePeriod = false;
    _graceEndAt = null;
    _endAt = null;
    _remainingSeconds = 0;
    _totalSeconds = 0;
    _nativeScheduleDegraded = false;
    _reconciliationPending = false;
    _revisionDurationKnown = true;
    _emergencyInProgress = false;
    _sessionToken = null;
    _armedTarget = null;

    var persistedProjectionCleared = true;
    try {
      await _clearPersistedState();
      final prefs = await SharedPreferences.getInstance();
      persistedProjectionCleared = !prefs.containsKey(_stateKey);
      if (!_isSafeWalk) {
        persistedProjectionCleared =
            persistedProjectionCleared &&
            !prefs.containsKey(_activeKey) &&
            !prefs.containsKey(_totalSecondsKey) &&
            !prefs.containsKey(_endAtKey) &&
            !prefs.containsKey(_graceEndAtKey);
      }
    } catch (_) {
      persistedProjectionCleared = false;
    }
    if (_sideEffectsEnabled) {
      await _bestEffort(
        () => KoruBeniForegroundService.stop(owner: _foregroundOwner),
      );
    }
    notifyListeners();
    return persistedProjectionCleared;
  }

  Future<void> handleNativeGraceStarted() async {
    final token = _sessionToken;
    if (!_isActive || token == null) return;
    final snapshot = await _platform.readEmergencySession(token);
    if (!snapshot.isPresent ||
        snapshot.lifecycleState != EmergencySessionLifecycle.armed) {
      return;
    }
    _sessionToken = snapshot.token ?? token;
    _endAt = snapshot.mainDeadline ?? _endAt;
    _graceEndAt = snapshot.finalDeadline ?? _graceEndAt;
    _armedTarget = snapshot.target ?? _armedTarget;
    await _reconcileWithClock();
    if (_sideEffectsEnabled && _isGracePeriod) {
      await _bestEffort(_showGraceNotification);
    }
  }

  Future<void> handleNativeExpired() async {
    if (!_isActive) return;
    await _triggerEmergency();
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

  void _startTickerForCurrentPhase() {
    if (!_isActive) return;
    if (_isGracePeriod) {
      _startGraceTicker();
    } else {
      _startMainTicker();
    }
  }

  Future<void> _bestEffort(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      debugPrint('CheckInService best-effort operation failed');
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _cancelTicker();
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
