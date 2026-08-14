// ============================================================================
// UYGULAMA YAŞAM DÖNGÜSÜ – Arka plandan dönüşte yeniden kimlik doğrulama
// ============================================================================

import 'package:flutter/material.dart';
import '../../screens/app_unlock_screen.dart';
import '../navigation/app_navigator.dart';
import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';

/// Whether a lifecycle state means the app GENUINELY went to the background and
/// the re-auth clock should start.
///
/// Deliberately EXCLUDES [AppLifecycleState.inactive], and that exclusion is the
/// whole point. `inactive` fires while the view is still visible (system
/// dialogs, an incoming call, split-screen) AND -- critically -- it fires again
/// on the way BACK IN, immediately before `resumed`. Treating it as
/// backgrounding meant the resume transition overwrote the paused timestamp with
/// the current time, so the elapsed background time computed as ~0 and the lock
/// NEVER fired, at any duration. Measured on device: 141 s in the background
/// produced no lock screen.
///
/// `app_privacy_shield.dart` already draws exactly this distinction, for exactly
/// this reason; this handler simply disagreed with it.
bool lifecycleStartsBackgroundClock(AppLifecycleState state) =>
    state == AppLifecycleState.paused ||
    state == AppLifecycleState.hidden ||
    state == AppLifecycleState.detached;

/// Tracks app lifecycle and forces re-authentication after being
/// backgrounded for longer than [lockAfterSeconds].
class AppLifecycleHandler {
  AppLifecycleHandler._();
  static final AppLifecycleHandler instance = AppLifecycleHandler._();

  /// How many seconds in background before requiring re-auth.
  static const int lockAfterSeconds = 120; // 2 minutes

  DateTime? _pausedAt;
  bool _isLockScreenShowing = false;

  /// Called when the app goes to the background.
  ///
  /// The EARLIEST timestamp wins. Android emits several background states in a
  /// row (hidden then paused); overwriting on each would shorten the measured
  /// background time. Defence in depth alongside
  /// [lifecycleStartsBackgroundClock].
  void onPaused() {
    _pausedAt ??= DateTime.now();
  }

  /// Visible for tests: the background clock, or null when the app is foreground.
  @visibleForTesting
  DateTime? get pausedAt => _pausedAt;

  /// Visible for tests: reset between cases.
  @visibleForTesting
  void resetForTest() {
    _pausedAt = null;
    _isLockScreenShowing = false;
  }

  /// Called when app resumes. Shows lock screen if too much time has passed.
  Future<void> onResumed() async {
    if (_isLockScreenShowing) return;
    if (_pausedAt == null) return;

    final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
    _pausedAt = null;

    if (elapsed < lockAfterSeconds) return;
    // Check if PIN is set — no lock if user hasn't set one.
    final secureStorage = serviceLocator<SecureStorage>();
    final pin = await secureStorage.read(key: SecureStorageKeys.userPin);
    if (pin == null || pin.isEmpty) return;

    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;

    _isLockScreenShowing = true;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => AppUnlockScreen(
          onUnlocked: () {
            _isLockScreenShowing = false;
            navigator.pop();
          },
        ),
      ),
    );
    // If user pops back without unlocking (e.g. back button), reset flag
    _isLockScreenShowing = false;
  }
}
