import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_lifecycle_handler.dart';
import '../services/panic_countdown_guard.dart';
import '../services/subscription_gate.dart';
import '../../screens/check_in_screen.dart';
import '../../screens/safety_timeline_screen.dart';
import '../../screens/subscription/paywall_screen.dart';
import 'app_destination.dart';

/// Turns a validated destination into navigation, ONE gate at a time.
///
/// This runs only from inside `MainNavigation`, which `SplashScreen` builds
/// after consent, onboarding and the PIN gate. So by the time anything here
/// executes, the identity and consent gates are already satisfied — this layer's
/// remaining job is the entitlement gate, and it asks the SAME function every
/// in-app tap asks (`SubscriptionGate.ensureAccess`) with the SAME feature.
/// Handing a link a private authorization path is how a paywall acquires a
/// bypass.
abstract final class DestinationRouter {
  /// Result of one routing attempt, so the caller can report rather than guess.
  static Future<DestinationRouteOutcome> route(
    BuildContext context,
    AppDestination destination, {
    required void Function(int index) selectTab,
  }) async {
    final blocked = _deferral();
    if (blocked != null) return blocked;
    final feature = destination.gatedFeature;
    if (feature != null) {
      final allowed = await SubscriptionGate.ensureAccess(context, feature);
      if (!allowed) return DestinationRouteOutcome.refusedByEntitlement;
      if (!context.mounted) return DestinationRouteOutcome.contextGone;
      // The gate can take seconds; the re-auth lock may have gone up since,
      // or a panic countdown opened. Pushing now would land ABOVE either.
      final late = _deferral();
      if (late != null) return late;
    }

    final tab = destination.tabIndex;
    if (tab != null) {
      selectTab(tab);
      return DestinationRouteOutcome.shown;
    }

    final Widget screen = switch (destination) {
      AppDestination.safetyTimeline => const SafetyTimelineScreen(),
      AppDestination.checkIn => const CheckInScreen(),
      AppDestination.subscription => const PaywallScreen(),
      // Every tab-backed destination returned above; this branch exists so a
      // NEW destination fails to compile rather than silently doing nothing.
      AppDestination.home ||
      AppDestination.map ||
      AppDestination.contacts ||
      AppDestination.settings => throw StateError(
        'tab destination ${destination.slug} reached the push branch',
      ),
    };

    // Not awaited: routing ends once the screen is up. Awaiting the pop kept
    // the caller's single-flight flag raised while the screen stayed open, so
    // a second link was parked and fired at some later resume (audit A-08).
    unawaited(
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen)),
    );
    return DestinationRouteOutcome.shown;
  }

  /// Why routing must wait right now, or null when it may proceed.
  static DestinationRouteOutcome? _deferral() {
    if (AppLifecycleHandler.instance.lockActive.value) {
      return DestinationRouteOutcome.deferredByLock;
    }
    // A live panic countdown owns the screen: a destination above it hides
    // the PIN-cancel pad while the clock runs (audit A-06).
    if (PanicCountdownGuard.isHeld) {
      return DestinationRouteOutcome.deferredByCountdown;
    }
    return null;
  }
}

enum DestinationRouteOutcome {
  /// The destination was displayed.
  shown,

  /// The subscription gate refused. It has already told the user why — the
  /// link layer must not add a second, differently-worded refusal.
  refusedByEntitlement,

  /// The widget went away mid-gate. Nothing was shown and nothing is retried:
  /// a link that survives its own screen would fire at an arbitrary later
  /// moment.
  contextGone,

  /// The re-auth lock is up. Nothing was shown; the caller re-parks the
  /// destination so it is routed after unlock, never over the lock.
  deferredByLock,

  /// A panic countdown is on screen. Nothing was shown; the caller re-parks
  /// the destination so it is routed once the countdown has closed.
  deferredByCountdown,
}
