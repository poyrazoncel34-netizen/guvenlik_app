import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../services/app_lifecycle_handler.dart';
import '../services/emergency_readiness_service.dart';
import '../services/local_logger_service.dart';
import '../services/panic_countdown_guard.dart';
import '../utils/permission_helper.dart';

typedef PhoneGroupStatus = Future<PermissionStatus> Function();
typedef SimSelectionPrompt = Future<void> Function(BuildContext context);

/// Asks an install that already holds CALL_PHONE, once, for the rest of the
/// phone group (READ_PHONE_STATE), which native needs to put the emergency
/// call on an explicit SIM (2026-11-06).
///
/// READ_PHONE_STATE was added to the manifest after CALL_PHONE. The
/// arm-refusal flow asks only for what native refuses on, and CALL_PHONE is
/// not missing on such an install, so nothing else would ever ask. Without it
/// a dual-SIM phone set to "ask every time" parks the emergency call in the
/// SIM picker, which a locked or pocketed phone never answers.
///
/// Nothing here gates a panic: a decline only leaves the call without an
/// explicit account, as before. Asked at most once whatever the answer. Never
/// above the resume PIN lock (audit A-07): like PanicReadinessSetup it waits
/// for the lock to come down, so a lock raised while the readiness probe runs
/// defers the offer instead of dropping it for this start. Never above a live
/// panic countdown (A-06): that start skips it and the next one asks.
abstract final class SimSelectionOffer {
  static Future<void> offerOnce(
    BuildContext context, {
    required bool emergencyAuthorized,
    EmergencyReadinessService? readiness,
    PhoneGroupStatus? phoneStatus,
    SimSelectionPrompt? prompt,
  }) async {
    if (!emergencyAuthorized) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(AppConstants.prefSimSelectionOffered) ?? false) return;

    final state = await (readiness ?? EmergencyReadinessService.instance)
        .checkReadiness();
    // Unknown decides nothing. Without CALL_PHONE the call-permission
    // disclosure requests the whole phone group, READ_PHONE_STATE included.
    if (!state.isKnown || !state.callPermission) return;

    final status = await (phoneStatus ?? () => Permission.phone.status)();
    if (status.isGranted || status.isPermanentlyDenied || status.isRestricted) {
      await prefs.setBool(AppConstants.prefSimSelectionOffered, true);
      return;
    }

    final lock = AppLifecycleHandler.instance.lockActive;
    while (lock.value) {
      await _unlocked(lock);
    }
    if (!context.mounted) return;
    // Read after the last await, with nothing awaited before the prompt.
    if (lock.value || PanicCountdownGuard.isHeld) return;

    await prefs.setBool(AppConstants.prefSimSelectionOffered, true);
    if (!context.mounted) return;
    try {
      await (prompt ?? PermissionHelper.requestSimSelectionPermission)(context);
    } on PlatformException {
      // A permission request already running: the call path is unaffected.
      await _logFailed();
    } on MissingPluginException {
      await _logFailed();
    }
  }

  /// Completes once [lock] is down: the wait PanicReadinessSetup does.
  static Future<void> _unlocked(ValueListenable<bool> lock) {
    final unlocked = Completer<void>();
    void listener() {
      if (lock.value) return;
      lock.removeListener(listener);
      if (!unlocked.isCompleted) unlocked.complete();
    }

    lock.addListener(listener);
    listener();
    return unlocked.future;
  }

  static Future<void> _logFailed() => LocalLoggerService.instance.warningCode(
    LocalWarningCode.panicSetupStepFailed,
  );
}
