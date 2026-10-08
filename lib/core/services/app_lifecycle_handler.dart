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
import 'app_reset_state_registry.dart';
import 'emergency_platform_service.dart';
import 'emergency_session_contract.dart';
import 'panic_countdown_guard.dart';
import 'pin_lockout_service.dart' show MonotonicReading;

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
    Future<MonotonicReading?> Function()? monotonic,
  }) : _now = now ?? DateTime.now,
       _secureStorage = secureStorage,
       _monotonic =
           monotonic ?? EmergencyPlatformService.instance.readMonotonicClock;

  factory AppLifecycleHandler.forTesting({
    required DateTime Function() now,
    required SecureStorage secureStorage,
    Future<MonotonicReading?> Function()? monotonic,
  }) => AppLifecycleHandler._(
    now: now,
    secureStorage: secureStorage,
    monotonic: monotonic ?? () async => null,
  );

  static final AppLifecycleHandler instance = AppLifecycleHandler._()
    .._endLockOnDataWipe();

  final DateTime Function() _now;
  final SecureStorage? _secureStorage;

  /// Native elapsedRealtime, which nobody can set and which counts sleep.
  /// The wall clock alone let a clock set back skip the lock (audit Y-10).
  final Future<MonotonicReading?> Function() _monotonic;
  Future<MonotonicReading?>? _pausedReading;

  /// How many seconds in background before requiring re-auth.
  static const int lockAfterSeconds = 120; // 2 minutes

  /// Same budget PinVerificationService gives a secure-storage read.
  static const Duration pinReadTimeout = Duration(seconds: 2);

  /// Name of the resume lock route, so stack-wide navigation can stop at it.
  static const String lockRouteName = 'korubeni/resume-lock';

  /// Longest the lock defers to a live panic countdown. A countdown ends ten
  /// seconds after it starts; a guard still held long after that is a leak,
  /// and a leak must not switch the lock off for the rest of the process.
  static const Duration maxCountdownDeferral = Duration(seconds: 60);

  /// Completed local-data wipes in this process. The ONE event, besides a
  /// verified unlock, that may end the lock: "forgot PIN" wipes, then pops it.
  int _completedWipes = 0;

  void _endLockOnDataWipe() =>
      AppResetStateRegistry.register(this, () => _completedWipes++);

  /// Whether [route] is the resume PIN lock.
  static bool isLockRoute(Route<dynamic> route) =>
      route.settings.name == lockRouteName;

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
    if (_pausedAt != null) return;
    _pausedAt = _now();
    _pausedReading = _readMonotonic();
  }

  Future<MonotonicReading?> _readMonotonic() async {
    try {
      return await _monotonic();
    } on Exception {
      return null;
    }
  }

  /// Whether elapsedRealtime says the background lasted the lock threshold.
  Future<bool> _monotonicSaysLong(Future<MonotonicReading?>? paused) async {
    final before = await paused;
    if (before == null) return false;
    final after = await _readMonotonic();
    return after != null &&
        after.bootCount == before.bootCount &&
        after.elapsedMs - before.elapsedMs >= lockAfterSeconds * 1000;
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
    _pausedReading = null;
    _lockActive.value = false;
  }

  /// Called when app resumes. Shows lock screen if too much time has passed.
  Future<void> onResumed() async {
    // Foreground again either way. Leaving the stamp behind while the lock was
    // already up let a LATER, brief background inherit this old timestamp and
    // re-lock at once.
    final pausedAt = _pausedAt;
    final pausedReading = _pausedReading;
    _pausedAt = null;
    _pausedReading = null;
    if (_lockActive.value || pausedAt == null) return;

    final elapsed = _now().difference(pausedAt).inSeconds;
    // Raised before the first await either way: a link collected during this
    // resume must not route while the decision is still being made.
    _lockActive.value = true;
    try {
      if (elapsed < lockAfterSeconds &&
          !await _monotonicSaysLong(pausedReading)) {
        return;
      }
      if (await _readPinState() == PinState.absent) return;
      final wipesAtLock = _completedWipes;
      while (true) {
        // Never ABOVE a live panic countdown: it is a deliberate no-PIN
        // surface, and covering it hides the only PIN-cancel pad while the
        // clock runs. The lock follows as soon as the countdown closes.
        await PanicCountdownGuard.whenReleased(timeout: maxCountdownDeferral);
        final navigator = rootNavigatorKey.currentState;
        if (navigator == null) return;
        if (await _showLock(navigator)) return;
        // Removed by something other than a verified unlock -- a stack-wide
        // `popUntil`, a replacement aimed at "the top route". Only a completed
        // wipe may end the lock that way; anything else gets it back at once,
        // with no storage read first, so the app is never left exposed.
        if (_completedWipes != wipesAtLock) return;
      }
    } finally {
      // Lowered only once the lock route is GONE (unlock, back, or a wipe
      // popping it): lowering it first would let a parked link push itself
      // above the lock just before `pop` removed the topmost route.
      _lockActive.value = false;
    }
  }

  Future<PinState> _readPinState() async {
    // Check if PIN is set — no lock if user hasn't set one.
    final secureStorage = _secureStorage ?? serviceLocator<SecureStorage>();
    try {
      // Bounded: the lock flag is already up, and a read that never returned
      // would keep it up -- no re-lock, no link routing -- for the rest of
      // the process. A timeout is a read failure, which shows the lock.
      final pin = await secureStorage
          .read(key: SecureStorageKeys.userPin)
          .timeout(pinReadTimeout);
      return pin == null || pin.isEmpty
          ? PinState.absent
          : PinState.configured;
    } catch (_) {
      // Storage uncertainty is never evidence that no PIN exists. Route to
      // the existing local-PIN recovery surface instead of exposing the app.
      return PinState.readFailed;
    }
  }

  /// Shows the lock until it is removed; true only for a verified unlock.
  Future<bool> _showLock(NavigatorState navigator) async {
    var unlocked = false;
    late final Route<void> lock;
    lock = MaterialPageRoute<void>(
      settings: const RouteSettings(name: lockRouteName),
      builder: (_) => AppUnlockScreen(
        onUnlocked: () {
          unlocked = true;
          // THIS route, not the top one: a countdown pushed above the lock
          // while the PIN was being verified must not be what closes.
          if (lock.isCurrent) {
            navigator.pop();
          } else if (lock.isActive) {
            navigator.removeRoute(lock);
          }
        },
      ),
    );
    await navigator.push(lock);
    return unlocked;
  }
}
