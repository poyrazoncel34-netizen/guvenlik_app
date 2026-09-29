import 'package:flutter/material.dart';

import '../core/motion.dart';
import 'splash_screen.dart';

/// The one and only route this app ever puts at the bottom of its Navigator.
///
/// ## Why this exists
///
/// Startup used to move between its four top-level destinations -- consent,
/// onboarding, unlock, home -- with `pushReplacement` / `pushAndRemoveUntil`.
/// Every one of those calls DESTROYS the initial route, and an app whose
/// initial route is gone cannot restore its Navigator: on a real Android
/// process death the restored route history comes back EMPTY, trips
/// `assert(_history.isNotEmpty)` in navigator.dart, and the user gets the crash
/// screen instead of their app. Measured on an API 36 emulator before this
/// shell existed: 28 framework errors within 10 s of returning from
/// `adb shell am kill`. The reproduction is kept as an executable test in
/// `test/screens/state_restoration_navigator_precondition_test.dart`.
///
/// So the destinations became STATE rather than routes. `/` is [AppRoot], it is
/// never popped or replaced, and it is restorable -- which is what lets
/// `MaterialApp.restorationScopeId` be switched on at all, and with it the
/// restoration of a half-typed emergency contact.
///
/// ## Why this is also the safer shape
///
/// [_destination] is deliberately NOT restorable. After a process death the
/// shell starts at [SplashScreen] again and re-runs the whole decision --
/// including the PIN gate. Under the old route-based startup the unlock screen
/// sat at the BOTTOM of the stack (it was reached by `pushReplacement`), so any
/// route restored from the previous session would have been re-inserted ABOVE
/// it and the user would have come back looking at their data with the lock
/// parked underneath. Here that cannot happen: restored widget state cannot
/// make a destination appear, only [SplashScreen] can choose one.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  /// Restarts the startup decision without destroying the Navigator's initial
  /// route.
  ///
  /// A completed local-data wipe must return to consent/onboarding, but using
  /// `pushAndRemoveUntil((_) => false)` for that transition removes `/`. With
  /// route restoration enabled, the next Android process recreation then has
  /// no restorable history and fails in `Navigator._history.isNotEmpty` before
  /// the app can render. Descendants hosted by [AppRoot] use this state reset;
  /// standalone screens can retain their historical navigation fallback.
  static bool restartStartup(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_AppRootRestartScope>();
    if (scope == null) return false;
    scope.restart();
    return true;
  }

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  /// Null until SplashScreen has decided. Never restored on purpose -- see the
  /// class comment.
  Widget? _destination;

  void _show(Widget destination) {
    if (!mounted) return;
    setState(() => _destination = destination);
  }

  void _restart() {
    if (!mounted) return;
    setState(() => _destination = null);
  }

  @override
  Widget build(BuildContext context) {
    // Reproduces the transition the four `pushReplacement` calls used to draw:
    // a fade over [Motion.slow]. Swapping destinations must not look like a
    // different app than the one that shipped.
    return _AppRootRestartScope(
      restart: _restart,
      child: AnimatedSwitcher(
        duration: Motion.slow,
        child: _destination ?? SplashScreen(advance: _show),
      ),
    );
  }
}

class _AppRootRestartScope extends InheritedWidget {
  const _AppRootRestartScope({required this.restart, required super.child});

  final VoidCallback restart;

  @override
  bool updateShouldNotify(_AppRootRestartScope oldWidget) => false;
}
