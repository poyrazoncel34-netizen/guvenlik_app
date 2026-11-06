import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../services/app_lifecycle_handler.dart';
import '../services/arm_remedy.dart';
import '../services/emergency_readiness_service.dart';
import '../services/local_logger_service.dart';
import '../services/panic_countdown_guard.dart';
import '../utils/permission_helper.dart';
import 'exact_alarm_permission_guard.dart';

/// Shows the prompt for one setup step; true when it opened Android Settings,
/// so the setup waits for the user to come back before probing again.
typedef PanicSetupPrompt =
    Future<bool> Function(BuildContext context, ArmRemedy step);

/// Asks, one at a time, for what a protected panic needs (2026-11-02).
///
/// Native refuses a panic without exact-alarm access, CALL_PHONE,
/// notifications or a high-importance alert channel, and the refusal rule is
/// deliberate. On an Android 14+ clean install exact-alarm access is OFF by
/// default, so a Pro user who skipped the onboarding step met the refusal at
/// their first real panic. This runs when Pro is activated (paywall) and on the
/// first start of an install that is already Pro (MainNavigation).
///
/// The steps follow native refusal order and use the existing prompts: the
/// exact-alarm dialog of [requireExactAlarmPermission], the CALL_PHONE
/// disclosure, and the "go to settings" dialog of [PermissionHelper]. Every
/// step can be declined; each is asked at most once per run, and readiness is
/// read again after every step, because one trip to Settings can fix more
/// than one thing, or nothing. A reading that predates the last trip can only
/// be stale about what that trip changed: its step is never asked again, and
/// one it fixed on the way costs a prompt the user can skip.
abstract final class PanicReadinessSetup {
  static Future<void> run(
    BuildContext context, {
    EmergencyReadinessService? readiness,
    PanicSetupPrompt prompt = askFor,
  }) async {
    final service = readiness ?? EmergencyReadinessService.instance;
    final asked = <ArmRemedy>{};
    while (context.mounted) {
      final state = await service.checkReadiness();
      if (!context.mounted) return;
      ArmRemedy? next;
      for (final step in ArmRemedy.missingCapabilities(state)) {
        if (!asked.contains(step)) {
          next = step;
          break;
        }
      }
      if (next == null) {
        // Done only on a real reading. A probe that went unanswered decided
        // nothing, and the steps after it were never asked: the next start
        // offers the setup again (review 2026-11-06).
        if (state.isKnown) await _markOffered();
        return;
      }
      // Never above the resume PIN lock (audit A-07), nor above a live panic
      // countdown and its PIN-cancel pad (A-06). Both are read after the
      // probe, which can outlast a resume, and nothing is awaited between
      // reading them and the prompt. A lock means time has passed: the device
      // is read again once it is down. A panic ends the setup; the next start
      // asks again.
      final lock = AppLifecycleHandler.instance.lockActive;
      if (lock.value) {
        await _unlocked(lock);
        continue;
      }
      if (PanicCountdownGuard.isHeld) return;
      asked.add(next);
      final away = _AwayFromApp();
      try {
        if (await prompt(context, next)) await away.untilBack();
      } on PlatformException {
        // A permission request already running, a Settings screen that
        // would not open: this step is skipped, the others are still asked.
        await _logStepFailed();
      } on MissingPluginException {
        await _logStepFailed();
      } finally {
        away.dispose();
      }
    }
  }

  static Future<void> _markOffered() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefPanicReadinessSetupOffered, true);
  }

  static Future<void> _logStepFailed() => LocalLoggerService.instance
      .warningCode(LocalWarningCode.panicSetupStepFailed);

  /// Completes once [lock] is down: the wait SubscriptionGate does before
  /// its paywall.
  static Future<void> _unlocked(ValueListenable<bool> lock) {
    final unlocked = Completer<void>();
    void listener() {
      if (lock.value) return;
      lock.removeListener(listener);
      if (!unlocked.isCompleted) unlocked.complete();
    }

    lock.addListener(listener);
    return unlocked.future;
  }

  /// First start of an install that is already allowed to panic: activated
  /// on another device, restored by the store, or bought before the paywall
  /// asked. A free install is not asked and stays eligible.
  static Future<void> offerOnce(
    BuildContext context, {
    required bool emergencyAuthorized,
    EmergencyReadinessService? readiness,
    PanicSetupPrompt prompt = askFor,
  }) async {
    if (!emergencyAuthorized) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(AppConstants.prefPanicReadinessSetupOffered) ?? false) {
      return;
    }
    if (!context.mounted) return;
    await run(context, readiness: readiness, prompt: prompt);
  }

  static Future<bool> askFor(BuildContext context, ArmRemedy step) async {
    switch (step) {
      case ArmRemedy.exactAlarm:
        return showExactAlarmPrompt(
          context,
          bodyKey: 'panic_setup_exact_alarm_body',
        );
      case ArmRemedy.callPermission:
        // A runtime dialog: it answers in-app.
        await PermissionHelper.requestCallPhonePermission(context);
        return false;
      case ArmRemedy.notifications:
        return PermissionHelper.requestNotificationSettings(context);
      case ArmRemedy.alertChannel:
        return PermissionHelper.requestAlertChannelHigh(context);
      case ArmRemedy.emergencyContact ||
          ArmRemedy.pinSetup ||
          ArmRemedy.pinSettings ||
          ArmRemedy.subscription:
        // Not device capabilities; run() never reaches these.
        return false;
    }
  }
}

/// Waits for the user to come back from a Settings screen. Armed BEFORE the
/// prompt opens Settings, so a quick leave is not missed. If the app never
/// left the foreground (the screen did not open), it waits no longer than
/// [_leaveGrace]; a user who never comes back releases it after [_awayCap].
class _AwayFromApp {
  _AwayFromApp() {
    _listener = AppLifecycleListener(
      onInactive: () {
        if (!_left.isCompleted) _left.complete();
      },
      onResume: () {
        if (_left.isCompleted && !_back.isCompleted) _back.complete();
      },
    );
  }

  static const Duration _leaveGrace = Duration(seconds: 2);
  static const Duration _awayCap = Duration(minutes: 10);

  late final AppLifecycleListener _listener;
  final Completer<void> _left = Completer<void>();
  final Completer<void> _back = Completer<void>();

  Future<void> untilBack() async {
    try {
      await _left.future.timeout(_leaveGrace);
      await _back.future.timeout(_awayCap);
    } on TimeoutException {
      // Never left, or never came back: probe now either way.
    }
  }

  void dispose() => _listener.dispose();
}
