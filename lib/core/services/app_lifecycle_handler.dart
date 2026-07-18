// ============================================================================
// UYGULAMA YAŞAM DÖNGÜSÜ – Arka plandan dönüşte yeniden kimlik doğrulama
// ============================================================================

import 'package:flutter/material.dart';
import '../../screens/app_unlock_screen.dart';
import '../navigation/app_navigator.dart';
import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';

/// Tracks app lifecycle and forces re-authentication after being
/// backgrounded for longer than [lockAfterSeconds].
class AppLifecycleHandler {
  AppLifecycleHandler._();
  static final AppLifecycleHandler instance = AppLifecycleHandler._();

  /// How many seconds in background before requiring re-auth.
  static const int lockAfterSeconds = 120; // 2 minutes

  DateTime? _pausedAt;
  bool _isLockScreenShowing = false;

  /// Called when app goes to background (paused / hidden / inactive).
  void onPaused() {
    _pausedAt = DateTime.now();
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
