// ============================================================================
// UYGULAMA YAŞAM DÖNGÜSÜ – Arka plandan dönüşte yeniden kimlik doğrulama
// ============================================================================

import 'package:flutter/material.dart';
import '../../screens/app_unlock_screen.dart';
import '../navigation/app_navigator.dart';
import '../widgets/app_privacy_shield.dart';
import 'emergency_session_contract.dart';
import 'pin_verification_service.dart';

bool resumeRequiresAuthentication({
  required Duration backgroundElapsed,
  required bool pinConfigured,
}) =>
    pinConfigured &&
    backgroundElapsed >=
        const Duration(seconds: AppLifecycleHandler.lockAfterSeconds);

/// Tracks app lifecycle and forces re-authentication after being
/// backgrounded for longer than [lockAfterSeconds].
class AppLifecycleHandler {
  AppLifecycleHandler._();
  static final AppLifecycleHandler instance = AppLifecycleHandler._();

  /// How many seconds in background before requiring re-auth.
  static const int lockAfterSeconds = 120; // 2 minutes

  Stopwatch? _backgroundStopwatch;
  bool _isLockScreenShowing = false;
  final AppPrivacyBarrierController _privacyBarrier =
      AppPrivacyBarrierController.instance;

  /// Called only for true background states (paused / hidden / detached).
  void onPaused() {
    _privacyBarrier.obscure();
    if (_backgroundStopwatch?.isRunning ?? false) return;
    _backgroundStopwatch = Stopwatch()..start();
  }

  /// Called when app resumes. Shows lock screen if too much time has passed.
  Future<void> onResumed() async {
    if (_isLockScreenShowing) {
      _privacyBarrier.reveal();
      return;
    }

    final stopwatch = _backgroundStopwatch;
    _backgroundStopwatch = null;
    if (stopwatch == null) {
      _privacyBarrier.reveal();
      return;
    }
    stopwatch.stop();
    final elapsed = stopwatch.elapsed.inSeconds;
    if (elapsed < lockAfterSeconds) {
      _privacyBarrier.reveal();
      return;
    }

    // An unreadable PIN store is not proof that no PIN exists. Keep the app
    // fail-closed and show the lock/recovery surface in that case.
    var pinConfiguredOrUnknown = true;
    try {
      final state = await PinVerificationService.instance.loadState();
      pinConfiguredOrUnknown = state != PinState.absent;
    } catch (_) {
      pinConfiguredOrUnknown = true;
    }
    if (!pinConfiguredOrUnknown) {
      _privacyBarrier.reveal();
      return;
    }

    var navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      await WidgetsBinding.instance.endOfFrame;
      navigator = rootNavigatorKey.currentState;
    }
    if (navigator == null) return;

    _isLockScreenShowing = true;
    try {
      final route = PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) =>
            AppUnlockScreen(onUnlocked: () => navigator!.pop()),
      );
      final completion = navigator.push(route);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _privacyBarrier.reveal();
      });
      await completion;
    } finally {
      _isLockScreenShowing = false;
    }
  }
}
