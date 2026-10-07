// ============================================================================
// UYGULAMA YAŞAM DÖNGÜSÜ – Arka plandan dönüşte yeniden kimlik doğrulama
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../screens/app_unlock_screen.dart';
import '../navigation/app_navigator.dart';
import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';
import 'emergency_session_contract.dart';

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
  AppLifecycleHandler._({
    DateTime Function()? now,
    SecureStorage? secureStorage,
  }) : _now = now ?? DateTime.now,
       _secureStorage = secureStorage;

  factory AppLifecycleHandler.forTesting({
    required DateTime Function() now,
    required SecureStorage secureStorage,
  }) => AppLifecycleHandler._(now: now, secureStorage: secureStorage);

  static final AppLifecycleHandler instance = AppLifecycleHandler._();

  final DateTime Function() _now;
  final SecureStorage? _secureStorage;

  /// How many seconds in background before requiring re-auth.
  static const int lockAfterSeconds = 120; // 2 minutes

  /// Same budget PinVerificationService gives a secure-storage read.
  static const Duration pinReadTimeout = Duration(seconds: 2);

  DateTime? _pausedAt;
  final ValueNotifier<bool> _lockActive = ValueNotifier<bool>(false);

  /// True from the instant a resume decides the app must re-authenticate
  /// until the re-auth lock route has been popped.
  ///
  /// The lock is a ROUTE above `/`, so anything else that pushes onto the root
  /// Navigator lands ABOVE it. Measured on an API 35 emulator: with the lock
  /// up, `korubeni://open/timeline` opened the safety timeline over it, no PIN
  /// asked. External-entry routing therefore waits on this flag. It is raised
  /// BEFORE the first await below, so a link collected during the same resume
  /// already sees it.
  ValueListenable<bool> get lockActive => _lockActive;

  /// Called when the app goes to the background.
  ///
  /// The EARLIEST timestamp wins. Android emits several background states in a
  /// row (hidden then paused); overwriting on each would shorten the measured
  /// background time. Defence in depth alongside
  /// [lifecycleStartsBackgroundClock].
  void onPaused() {
    _pausedAt ??= _now();
  }

  /// Visible for tests: the background clock, or null when the app is foreground.
  @visibleForTesting
  DateTime? get pausedAt => _pausedAt;

  /// Visible for tests: backdates the background clock of [instance], whose
  /// clock is the real one.
  @visibleForTesting
  set pausedAtForTest(DateTime? value) => _pausedAt = value;

  /// Visible for tests: reset between cases.
  @visibleForTesting
  void resetForTest() {
    _pausedAt = null;
    _lockActive.value = false;
  }

  /// Called when app resumes. Shows lock screen if too much time has passed.
  Future<void> onResumed() async {
    // Foreground again either way. Leaving the stamp behind while the lock was
    // already up let a LATER, brief background inherit this old timestamp and
    // re-lock at once.
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (_lockActive.value || pausedAt == null) return;

    final elapsed = _now().difference(pausedAt).inSeconds;
    if (elapsed < lockAfterSeconds) return;
    _lockActive.value = true;
    try {
      // Check if PIN is set — no lock if user hasn't set one.
      final secureStorage = _secureStorage ?? serviceLocator<SecureStorage>();
      PinState pinState;
      try {
        // Bounded: the lock flag is already up, and a read that never returned
        // would keep it up -- no re-lock, no link routing -- for the rest of
        // the process. A timeout is a read failure, which shows the lock.
        final pin = await secureStorage
            .read(key: SecureStorageKeys.userPin)
            .timeout(pinReadTimeout);
        pinState = pin == null || pin.isEmpty
            ? PinState.absent
            : PinState.configured;
      } catch (_) {
        // Storage uncertainty is never evidence that no PIN exists. Route to
        // the existing local-PIN recovery surface instead of exposing the app.
        pinState = PinState.readFailed;
      }
      if (pinState == PinState.absent) return;

      final navigator = rootNavigatorKey.currentState;
      if (navigator == null) return;

      await navigator.push(
        MaterialPageRoute(
          builder: (_) => AppUnlockScreen(onUnlocked: () => navigator.pop()),
        ),
      );
    } finally {
      // Lowered only once the lock route is GONE (unlock, back, or a wipe
      // popping it): lowering it first would let a parked link push itself
      // above the lock just before `pop` removed the topmost route.
      _lockActive.value = false;
    }
  }
}
