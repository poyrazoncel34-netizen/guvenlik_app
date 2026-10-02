import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../navigation/app_navigator.dart';
import '../services/overlay_touch_guard.dart';

/// Applies an [OverlayTouchPolicy] while the mixing [State] is mounted, and
/// tells the user when another app is drawing over it.
///
/// A mixin rather than a wrapper widget, deliberately. The guarded surfaces have
/// long `build` methods, and nesting them one level deeper would re-indent
/// roughly two hundred pre-existing lines per screen -- churn this repository
/// explicitly refuses, because it buries the real change and destroys blame on a
/// safety-critical file. It also keeps ONE way to claim the policy instead of a
/// widget and a service call that can drift apart.
///
/// The warning is a SnackBar, not a new layout element: the consent and PIN
/// screens are laid out deliberately and this must not reflow them.
mixin OverlayTouchShield<T extends StatefulWidget> on State<T> {
  /// Unique per surface. Two surfaces may be stacked -- a dialog over a guarded
  /// screen -- and releasing one must not drop the other's protection.
  String get overlayGuardOwner;

  /// [OverlayTouchPolicy.warn] for gateway surfaces, [OverlayTouchPolicy.block]
  /// for everything else. See [OverlayTouchPolicy] for why the two are not
  /// interchangeable.
  OverlayTouchPolicy get overlayGuardPolicy;

  /// Overridable so tests can inject a guard with a mock channel.
  @visibleForTesting
  OverlayTouchGuard get overlayGuard => OverlayTouchGuard.instance;

  @override
  void initState() {
    super.initState();
    overlayGuard.lastObscuredTouch.addListener(_onObscuredTouch);
    unawaited(overlayGuard.acquire(overlayGuardOwner, overlayGuardPolicy));
  }

  @override
  void dispose() {
    overlayGuard.lastObscuredTouch.removeListener(_onObscuredTouch);
    // Not awaited: dispose cannot be async, and a lease outliving its surface by
    // one frame is harmless -- the next acquire or release pushes the correct
    // policy to the window.
    unawaited(overlayGuard.release(overlayGuardOwner));
    super.dispose();
  }

  void _onObscuredTouch() {
    if (!mounted || overlayGuard.lastObscuredTouch.value == null) return;
    final messenger =
        ScaffoldMessenger.maybeOf(context) ??
        rootScaffoldMessengerKey.currentState;
    // One message at a time: a second surface activating must not stack a queue
    // of identical warnings that outlive the situation.
    messenger?.removeCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('overlay_touch_warning'.tr()),
        backgroundColor: AppColors.emergency,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }
}
