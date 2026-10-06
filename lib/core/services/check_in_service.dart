// ============================================================================
// CHECK-IN / SAFE-WALK SERVİSİ (paylaşılan grace + dead-man's-switch)
// ============================================================================

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/models/activity_event.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../../screens/emergency_call_screen.dart';
import '../di/service_locator.dart';
import '../navigation/app_navigator.dart';
import '../services/activity_service.dart';
import '../services/android_intent_service.dart';
import '../services/call_service.dart';
import '../services/check_in_expiry_coordinator.dart';
import '../services/dispatch_ledger_recorder.dart';
import '../services/dispatch_outcome.dart';
import '../services/emergency_platform_service.dart';
import '../services/emergency_session_contract.dart';
import '../services/foreground_service.dart';
import '../services/haptic_service.dart';
import '../services/local_logger_service.dart';
import '../services/notification_service.dart';
import '../services/check_in_projection_store.dart';
import '../services/countdown_clock.dart';
import '../services/native_emergency_history.dart';
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
    bool sideEffectsEnabled = true,
  }) : _platform = platform ?? EmergencyPlatformService.instance,
       _contactsRepositoryOverride = contactsRepository,
       _sideEffectsEnabled = sideEffectsEnabled;

  factory CheckInService.forTesting({
    required String sessionId,
    required EmergencyPlatformService platform,
    required ContactsRepository contactsRepository,
    bool sideEffectsEnabled = false,
  }) => CheckInService._(
    sessionId,
    platform: platform,
    contactsRepository: contactsRepository,
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
  final bool _sideEffectsEnabled;

  ContactsRepository get _contactsRepository =>
      _contactsRepositoryOverride ?? serviceLocator<ContactsRepository>();

  String get sessionId => _sessionId;
  String get _foregroundOwner => 'safety_session:$_sessionId';
  bool get _isSafeWalk =>
      _sessionId == CheckInExpiryCoordinator.safeWalkSession;

  static const int _gracePeriodSeconds = 60;

  // Disk projection of this session; the native slot stays authoritative.
  CheckInProjectionStore get _projection =>
      CheckInProjectionStore(isSafeWalk: _isSafeWalk);

  // Per-session alert notification id (grace + emergency reuse the same id).
  int get _alertNotificationId => _isSafeWalk ? 9998 : 9999;

  Timer? _tickTimer;
  DateTime? _endAt;
  DateTime? _graceEndAt;
  bool _isActive = false;
  bool _isGracePeriod = false;
  bool _emergencyInProgress = false;
  bool _mutationInProgress = false;
  bool _nativeScheduleDegraded = false;
  SessionToken? _sessionToken;
  String? _armedTarget;
  ArmResult? _lastArmResult;
  CancelResult? _lastCancelResult;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;

  bool get isActive => _isActive;
  bool get isGracePeriod => _isGracePeriod;
  bool get nativeScheduleDegraded => _nativeScheduleDegraded;
  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  DateTime? get endAt => _isGracePeriod ? _graceEndAt : _endAt;
  SessionToken? get sessionToken => _sessionToken;
  ArmResult? get lastArmResult => _lastArmResult;
  CancelResult? get lastCancelResult => _lastCancelResult;

  Future<void> initialize() async {
    await _restoreFromStorage();
  }

  Future<void> handleAppResumed() async {
    await _restoreFromStorage();
  }

  /// Native-acknowledged arm. Dart becomes active only after [Armed].
  Future<ArmResult> startSession({
    required int minutes,
    required EntitlementDecision entitlementDecision,
    required bool pinConfigured,
  }) async {
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
    if (result is! Armed) {
      if (result is ArmUnknown && result.uncertainToken != null) {
        _sessionToken = result.uncertainToken;
        _nativeScheduleDegraded = true;
        notifyListeners();
      }
      return result;
    }

    _sessionToken = result.sessionToken;
    _armedTarget = target;
    _totalSeconds = totalSeconds;
    _remainingSeconds = totalSeconds;
    _isActive = true;
    _isGracePeriod = false;
    _endAt = result.mainDeadline;
    _graceEndAt = result.finalDeadline;
    _nativeScheduleDegraded = false;

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
    if (_mutationInProgress) return;
    _mutationInProgress = true;
    try {
      await _restoreFromStorageUnlocked();
    } finally {
      _mutationInProgress = false;
    }
  }

  Future<void> _restoreFromStorageUnlocked() async {
    // The NATIVE SLOT is the authority even if the projection never committed.
    // This used to run the other way round: a missing or corrupt blob
    // short-circuited restore, so an alarm Android had already accepted became
    // a session the UI could neither show nor cancel (F01). Discovery only
    // ADOPTS what native holds; it never synthesizes a new session.
    var totalSeconds = _totalSeconds;
    final stored = await _projection.read();
    if (stored != null) {
      _sessionToken ??= stored.token;
      totalSeconds = stored.totalSeconds ?? totalSeconds;
    }
    final snapshot = await _platform.discoverEmergencySession(
      _isSafeWalk
          ? EmergencySessionKind.safeWalk
          : EmergencySessionKind.checkIn,
    );
    // Temporary uncertainty is NOT absence. Keep the token and the projection
    // so the next read can reconcile the same session, and surface the degraded
    // state instead of showing a cancellation that was never confirmed.
    if (snapshot.status == SessionReadStatus.unknown ||
        snapshot.status == SessionReadStatus.corrupted ||
        snapshot.lifecycleState == EmergencySessionLifecycle.corrupted) {
      _nativeScheduleDegraded = true;
      notifyListeners();
      return;
    }
    if (snapshot.status == SessionReadStatus.absent ||
        snapshot.lifecycleState == EmergencySessionLifecycle.cancelled) {
      await _clearLocalProjection(stopForeground: true);
      return;
    }
    if (!snapshot.isPresent) return;
    _sessionToken = snapshot.token;
    _armedTarget = snapshot.target;
    _endAt = snapshot.mainDeadline;
    _graceEndAt = snapshot.finalDeadline;
    _nativeScheduleDegraded = false;
    if (snapshot.lifecycleState.isTerminal) {
      if (_sideEffectsEnabled) {
        await NativeEmergencyHistory.reconcilePending(_platform);
      }
      await _clearLocalProjection(stopForeground: true);
      return;
    }
    // Claimed/preparing cannot be projected as an active, safely cancellable
    // timer. Native stays authoritative and will reconcile.
    _isActive = snapshot.lifecycleState == EmergencySessionLifecycle.armed;
    _emergencyInProgress =
        snapshot.lifecycleState == EmergencySessionLifecycle.claimed;
    _totalSeconds = (snapshot.mainDurationSeconds ?? 0) > 0
        ? snapshot.mainDurationSeconds!
        : totalSeconds > 0
        ? totalSeconds
        : (_endAt?.difference(DateTime.now()).inSeconds ?? 1).clamp(1, 86400);
    if (!_isActive) {
      _cancelTicker();
      notifyListeners();
      return;
    }
    await _bestEffort(_persistState);
    await _reconcileWithClock();
  }

  Future<void> _reconcileWithClock() async {
    if (!_isActive || _endAt == null || _graceEndAt == null) {
      return;
    }

    // Rounded UP: truncating inSeconds reached native deadlines early.
    final now = DateTime.now();
    final mainRemaining = CountdownClock.secondsUntil(_endAt!, now: now);
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
    final graceRemaining = CountdownClock.secondsUntil(_graceEndAt!, now: now);
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

      final remaining = CountdownClock.secondsUntil(deadline);
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

      final remaining = CountdownClock.secondsUntil(deadline);
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
    _remainingSeconds = CountdownClock.secondsUntil(
      finalDeadline,
    ).clamp(0, _gracePeriodSeconds).toInt();

    await _bestEffort(_persistState);
    if (_sideEffectsEnabled) {
      await _bestEffort(_startBackgroundProtection);
      _lastGraceAlertOutcome = await _showGraceNotification();
    }
    _startGraceTicker();
    notifyListeners();
  }

  /// The outcome of the most recent grace warning, or null before one was
  /// attempted. Read by the Check-In screen so a suppressed warning is visible
  /// where the user is looking (MP-11-014).
  DispatchTargetOutcome? get graceAlertOutcome => _lastGraceAlertOutcome;
  DispatchTargetOutcome? _lastGraceAlertOutcome;

  /// Safe-Walk's lead-time warning, posted by the NATIVE session.
  ///
  /// It used to fire from the Safe-Walk screen's own listener, so leaving the
  /// screen -- never mind losing the process -- silently removed the user's
  /// early cue while the native alarm kept running (F02).
  Future<DispatchTargetOutcome> postPreWarning() async {
    final token = _sessionToken;
    return token == null
        ? DispatchTargetOutcome.handoffUnconfirmed
        : _platform.warnEmergencySession(token, preWarning: true);
  }

  /// Posts the 60-second grace warning and REPORTS what happened to it.
  ///
  /// The user's last cue before escalation, and the outcome is RECORDED, not
  /// dropped: it used to sit in `catch (_) { // not critical }`, which turned
  /// "notifications are off" into the same silence as "Android displayed it"
  /// (FIR-02). Scheduling is native so a dead Flutter process cannot cost the
  /// user the warning (F02).
  Future<DispatchTargetOutcome> _showGraceNotification() async {
    final token = _sessionToken;
    return token == null
        ? DispatchTargetOutcome.handoffUnconfirmed
        : _platform.warnEmergencySession(token);
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
        // state. It must still leave a trace: an unlogged unknown dispatch is
        // indistinguishable from a session that silently never expired.
        await LocalLoggerService.instance.warningCode(
          LocalWarningCode.safetySessionDispatchUnknown,
        );
        return;
      }
      if (dispatch.wasCancelled) {
        await _clearLocalProjection(stopForeground: true);
        return;
      }

      final primaryNumber = _armedTarget ?? '';
      // Parity with the panic path (countdown_screen `_executeEmergency`): a
      // rejected automatic request must still leave the user one tap from the
      // call. Without this, a CALL_PHONE revocation after arming ends as a
      // dead "failed" screen for Check-In / Safe Walk while panic degrades to
      // the dialer.
      var callResult = dispatch.requestWasSubmitted
          ? EmergencyCallResult.requested(primaryNumber)
          : EmergencyCallResult.failed(primaryNumber);
      if (!dispatch.requestWasSubmitted && primaryNumber.isNotEmpty) {
        final dialerOpened = await AndroidIntentService.openDialer(
          primaryNumber,
        );
        if (dialerOpened) {
          callResult = EmergencyCallResult.dialer(primaryNumber);
          await LocalLoggerService.instance.warningCode(
            LocalWarningCode.safetySessionDialerFallback,
          );
        }
      }

      await _clearLocalProjection(stopForeground: !callResult.isSuccess);

      // Per-target accounting, identical in vocabulary to the panic path
      // (MP-01-027). Check-In escalation had the same defect: three independent
      // targets whose failures went to debugPrint, so a run that dialled but
      // could not post the alert reached the user as unqualified success.
      final ledger = DispatchOutcomeLedger(dispatchId: token.randomId);
      DispatchLedgerRecorder.recordCallTargets(ledger, callResult);
      if (_sideEffectsEnabled) {
        await DispatchLedgerRecorder.runRecorded(
          ledger,
          DispatchTarget.safetyTimeline,
          () async {
            await NativeEmergencyHistory.reconcilePending(_platform);
            return null;
          },
        );
        await DispatchLedgerRecorder.runRecorded(
          ledger,
          DispatchTarget.haptic,
          () async {
            await HapticService.emergencyTriggered();
            return null;
          },
        );
        await DispatchLedgerRecorder.runRecorded(
          ledger,
          DispatchTarget.alertNotification,
          () => NotificationService.instance.showEmergencyAlert(
            id: _alertNotificationId,
            title: "check_in_emergency_title".tr(),
            body: "alarm_notification_body".tr(),
          ),
        );
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
                dispatchLedger: ledger,
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

  Future<void> _persistState() => _projection.write(
    isActive: _isActive,
    totalSeconds: _totalSeconds,
    endAt: _endAt,
    graceEndAt: _graceEndAt,
    token: _sessionToken,
  );

  Future<void> _clearLocalProjection({required bool stopForeground}) async {
    _cancelTicker();
    _isActive = false;
    _isGracePeriod = false;
    _graceEndAt = null;
    _endAt = null;
    _remainingSeconds = 0;
    _totalSeconds = 0;
    _nativeScheduleDegraded = false;
    _sessionToken = null;
    _armedTarget = null;

    await _bestEffort(_projection.clear);
    if (stopForeground && _sideEffectsEnabled) {
      await _bestEffort(
        () => KoruBeniForegroundService.stop(owner: _foregroundOwner),
      );
    }
    notifyListeners();
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
      // Second entry into the grace warning (native told us the grace window
      // opened). Same rule as the Dart-side entry: the outcome is recorded,
      // never dropped into a best-effort bare catch (FIR-02).
      _lastGraceAlertOutcome = await _showGraceNotification();
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
