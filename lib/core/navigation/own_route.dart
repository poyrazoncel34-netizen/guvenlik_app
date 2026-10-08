import 'package:flutter/widgets.dart';

/// Navigation that acts on the route that owns a [BuildContext], not on the
/// navigator's topmost route.
///
/// `Navigator.pop(context)` and `Navigator.pushReplacement(context, ...)` both
/// operate on the TOPMOST route of the enclosing navigator, whatever route
/// `context` belongs to. On the emergency surfaces that difference is not
/// academic: an external link, the resume PIN lock or a paywall can land above
/// a live countdown, and the countdown then closed or replaced THAT route.
/// Measured on an API 35 emulator: a `korubeni://open/timeline` link during a
/// Test Mode rehearsal left the rehearsal stuck at zero, unclosable, while its
/// "completed" pop removed the timeline. With a real panic the replacement hit
/// the resume lock and removed it without a PIN.
///
/// When the owning route IS the top route these calls are exactly the plain
/// Navigator calls, transitions included, so the ordinary path is unchanged.
abstract final class OwnRoute {
  /// Closes the route that owns [context] with [result].
  ///
  /// A route covered by another one is removed in place, so whatever sits
  /// above it stays where it is.
  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (route == null || route.isCurrent) {
      navigator.pop<T>(result);
      return;
    }
    if (route.isActive) navigator.removeRoute(route, result);
  }

  /// Replaces the route that owns [context] with [newRoute].
  ///
  /// A covered route is swapped in place: [newRoute] takes its slot BELOW the
  /// route above it, which keeps, for example, the resume lock on top.
  static void replace(BuildContext context, Route<Object?> newRoute) {
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (route == null || route.isCurrent) {
      navigator.pushReplacement(newRoute);
      return;
    }
    if (!route.isActive) {
      // Already removed by someone else: there is no slot to take, and the
      // result must still be shown rather than lost.
      navigator.push(newRoute);
      return;
    }
    navigator.replace(oldRoute: route, newRoute: newRoute);
  }
}
