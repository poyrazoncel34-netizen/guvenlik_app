import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../presentation/providers/subscription_provider.dart';
import '../../screens/countdown_screen.dart';
import '../constants/app_constants.dart';
import '../navigation/app_navigator.dart';
import '../services/app_lifecycle_handler.dart';
import '../services/check_in_expiry_coordinator.dart';
import '../services/check_in_service.dart';
import '../services/emergency_platform_service.dart';
import '../services/emergency_session_contract.dart';
import '../services/local_logger_service.dart';
import '../services/emergency_readiness_service.dart';
import '../services/quick_panic_request_service.dart';
import '../services/subscription_access_state.dart';
import '../services/subscription_gate.dart';
import '../services/volume_trigger_service.dart';

class EmergencyTriggerHost extends StatefulWidget {
  final Widget child;

  /// Route builder for the countdown, overridable so a test can exercise the
  /// duplicate-trigger boundary without standing up the whole dispatch screen.
  /// Production always uses the default.
  @visibleForTesting
  final Widget Function(EntitlementDecision decision)? countdownBuilder;

  const EmergencyTriggerHost({
    super.key,
    required this.child,
    this.countdownBuilder,
  });

  @override
  State<EmergencyTriggerHost> createState() => EmergencyTriggerHostState();
}

class EmergencyTriggerHostState extends State<EmergencyTriggerHost>
    with WidgetsBindingObserver {
  bool _countdownOpen = false;
  StreamSubscription<Map<String, dynamic>>? _platformEventsSubscription;

  /// Resolve the session controller for a native event (SPEC §6 — safe-walk
  /// shares the same controller as check-in, no separate CountdownScreen).
  CheckInService _controllerFor(String? sessionId) =>
      sessionId == CheckInExpiryCoordinator.safeWalkSession
      ? CheckInService.safeWalk
      : CheckInService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CheckInService.instance.initialize();
    CheckInService.safeWalk.initialize();
    unawaited(EmergencyReadinessService.instance.checkReadiness());
    _bindPlatformEvents();
    _consumeQuickPanicRequest();
    _startForegroundTriggers();
  }

  /// A widget or Quick Settings tap that happened before Flutter was attached.
  /// Routed through [_openCountdown], the same entry the volume trigger uses,
  /// so entitlement and the arm boundary are resolved in exactly one place.
  Future<void> _consumeQuickPanicRequest() async {
    final source = await QuickPanicRequestService.consume();
    if (source == null || !mounted) return;
    await _openCountdown();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(EmergencyReadinessService.instance.checkReadiness());
      _startForegroundTriggers();
      CheckInService.instance.handleAppResumed();
      CheckInService.safeWalk.handleAppResumed();
      _consumePendingTrigger();
      _consumeQuickPanicRequest();
      // Re-auth after prolonged background
      AppLifecycleHandler.instance.onResumed();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopForegroundTriggers();
      // Record background start time
      AppLifecycleHandler.instance.onPaused();
    }
  }

  void _startForegroundTriggers() {
    _startVolumeIfEnabled();
  }

  Future<void> _startVolumeIfEnabled() async {
    if (!VolumeTriggerService.isSupported) return;

    await VolumeTriggerService.instance.loadPreference();
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final volumeEnabled =
        prefs.getBool(AppConstants.prefVolumeTrigger) ?? false;
    if (volumeEnabled) {
      final subscription = context.read<SubscriptionProvider>();
      final access = await _resolveAccessBounded(subscription);
      if (!mounted) return;
      if (access.shouldShowPaywall) {
        await VolumeTriggerService.instance.setEnabled(false);
        return;
      }
      if (!SubscriptionGate.isAuthorized(access, PremiumFeature.volumeTrigger)) {
        // Unknown is not free and does not authorize a new safety session, but
        // it also must not erase the user's preference as if access were denied.
        return;
      }
      VolumeTriggerService.instance.startListening(
        onPanicTriggered: _openCountdown,
      );
    }
  }

  void _stopForegroundTriggers() {
    VolumeTriggerService.instance.stopListening();
  }

  void _bindPlatformEvents() {
    EmergencyPlatformService.instance.initialize();
    _platformEventsSubscription = EmergencyPlatformService.instance.events
        .listen((event) async {
          try {
            final type = event['type']?.toString();
            final sessionId = event['sessionId']?.toString();
            if (type == 'checkInGraceStarted') {
              await _controllerFor(sessionId).handleNativeGraceStarted();
              return;
            }
            if (type == 'checkInExpired') {
              await _handleCheckInExpired(sessionId: sessionId);
              return;
            }
            if (type == 'safetyClockChanged' ||
                type == 'emergencySessionDispatched') {
              // `emergencySessionDispatched` is what the alarm receivers
              // actually emit (CountdownAlarmReceiver / CheckInAlarmReceiver).
              // Native has already claimed, posted the fallback and asked
              // Telecom; Dart's job is to stop showing a session that has
              // finished. Reuse the resume reconciliation instead of a second
              // interpretation of native state.
              await Future.wait([
                CheckInService.instance.handleAppResumed(),
                CheckInService.safeWalk.handleAppResumed(),
              ]);
            }
          } catch (_) {
            // Native event handling must never crash the root widget.
            return;
          }
        });
    _consumePendingTrigger();
  }

  Future<void> _consumePendingTrigger() async {
    final pending = await EmergencyPlatformService.instance
        .consumePendingTrigger();
    if (pending == null) {
      return;
    }

    final type = pending['type']?.toString();
    final sessionId = pending['sessionId']?.toString();
    if (type == 'checkInGraceStarted') {
      await _controllerFor(sessionId).handleNativeGraceStarted();
      return;
    }
    if (type == 'checkInExpired') {
      await _handleCheckInExpired(sessionId: sessionId);
      return;
    }
    if (type == 'emergencySessionDispatched') {
      // A dispatch that happened while Flutter was dead. Consuming this
      // payload without acting on it left the local projection claiming a
      // session was still running after the call had already been placed.
      await Future.wait([
        CheckInService.instance.handleAppResumed(),
        CheckInService.safeWalk.handleAppResumed(),
      ]);
    }
  }

  Future<void> _handleCheckInExpired({String? sessionId}) async {
    // Both check-in and safe-walk delegate to their shared session controller.
    // The controller dedups against the native-fired flag and calls ONLY the
    // primary contact (SPEC §3.2). Safe-walk no longer opens CountdownScreen.
    await _controllerFor(sessionId).handleNativeExpired();
  }

  /// Entitlement resolution on a budget, mirroring [SubscriptionGate].
  ///
  /// The quick-access surfaces (widget, tile, volume keys) used to await
  /// `resolveAccess()` with no limit. That call can reach the store, and on a
  /// captive portal or one bar of signal it is slow rather than failing fast --
  /// an unbounded wait in front of a panic press is a delayed emergency call.
  /// The panic button never had this problem because it goes through
  /// SubscriptionGate; these entries bypassed it. Same budget, same fallback to
  /// the last known state, so all panic entries now decide within the same
  /// worst case.
  Future<SubscriptionAccessState> _resolveAccessBounded(
    SubscriptionProvider subscription,
  ) async {
    try {
      await subscription.ensureOfflineGraceLoaded().timeout(
        SubscriptionGate.offlineAnchorLoadTimeout,
      );
    } on TimeoutException {
      // Degrades to "no anchor"; never blocks the press.
    }
    try {
      return await subscription.resolveAccess().timeout(
        SubscriptionGate.entitlementResolveTimeout,
      );
    } on TimeoutException {
      // A slow store answer is unresolved, which is what the grace window
      // inside entitlementDecision exists for.
      return subscription.access;
    }
  }

  /// Exercises the real trigger entry point. This is the exact callback
  /// `VolumeTriggerService.startListening` receives and `_consumeQuickPanicRequest`
  /// awaits; the platform gates on those two paths (`Platform.isAndroid`) make
  /// them unreachable from a host test, and the defect being guarded lives
  /// entirely inside [_openCountdown].
  @visibleForTesting
  Future<void> triggerPanicForTest() => _openCountdown();

  Future<void> _openCountdown() async {
    // ACQUIRED SYNCHRONOUSLY, before the first suspension point.
    //
    // This used to be written ~2.2s later, after `_resolveAccessBounded`
    // (400ms anchor + 1800ms store budget) and a frame await. Every trigger
    // arriving inside that window read `false` and proceeded, so two volume
    // patterns two seconds apart -- the natural behaviour when the first press
    // appears to do nothing -- stacked two CountdownScreen routes. The second
    // one's arm is rejected by the native coordinator with
    // `activeSessionExists`, which surfaces as a blocking total-failure dialog
    // ON TOP of the first, genuinely armed countdown, hiding its PIN-cancel.
    // See INDEPENDENT_REVIEW_ROUND_2.md R2-02.
    //
    // `PanicButton` already had this ordering right (`_pointerDown` is set in
    // the synchronous tap handler); this is the same invariant for the
    // quick-access entries.
    if (_countdownOpen) {
      return;
    }
    _countdownOpen = true;
    try {
      final subscription = context.read<SubscriptionProvider>();
      final access = await _resolveAccessBounded(subscription);
      if (!mounted) return;
      if (!SubscriptionGate.isAuthorized(access, PremiumFeature.panic)) {
        // Never a bare return: an unexplained no-op on a safety control is
        // indistinguishable from a crash (R2-03). Same surface the panic
        // button gets, via the same shared decision.
        await _reportRejection(access);
        return;
      }

      var navigator = rootNavigatorKey.currentState;
      if (navigator == null) {
        // Cold start: the request can arrive before the root navigator is
        // mounted. Dropping it here silently discarded the press, which on this
        // path is the whole feature. Retry once on the next frame.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        navigator = rootNavigatorKey.currentState;
        if (navigator == null) {
          // No navigator means no surface to explain on either. Record it so
          // the silence is at least diagnosable after the fact.
          await LocalLoggerService.instance.warningCode(
            LocalWarningCode.quickPanicNavigatorUnavailable,
          );
          return;
        }
      }

      // Parity with the panic button: the acknowledgement haptic is fired, not
      // awaited, and the route carries no transition. Awaiting the vibration
      // channel and then paying a 300ms MaterialPageRoute transition delayed
      // arming on the volume-trigger path only — the same session, slower.
      unawaited(
        HapticFeedback.heavyImpact().catchError((Object _) {
          debugPrint('EmergencyTriggerHost: acknowledgement haptic failed');
        }),
      );
      final decision = access.entitlementDecision;
      await navigator.push(
        PageRouteBuilder(
          pageBuilder: (_, _, _) =>
              widget.countdownBuilder?.call(decision) ??
              CountdownScreen(entitlementDecision: decision),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } finally {
      // Reset on EVERY exit -- success, early return, rejection, or a thrown
      // exception. A guard that could stay latched would disable the quick
      // access entries for the rest of the process.
      _countdownOpen = false;
    }
  }

  /// Routes a refused quick-access press to the shared rejection surface.
  ///
  /// Uses the root navigator's context, not the host's: the host lives above
  /// `MaterialApp`, so its own context has neither a `Navigator` nor a
  /// `ScaffoldMessenger`.
  Future<void> _reportRejection(SubscriptionAccessState access) async {
    final target = rootNavigatorKey.currentContext;
    if (target == null || !target.mounted) {
      await LocalLoggerService.instance.warningCode(
        LocalWarningCode.quickPanicNavigatorUnavailable,
      );
      return;
    }
    await SubscriptionGate.reportRejection(
      target,
      access,
      PremiumFeature.panic,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopForegroundTriggers();
    _platformEventsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
