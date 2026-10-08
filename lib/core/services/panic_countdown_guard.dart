import 'dart:async';

import 'package:flutter/foundation.dart';

/// One real panic countdown at a time, across EVERY entry point.
///
/// The in-app PanicButton and the quick-access host (volume keys, Quick
/// Settings tile, home-screen widget) push their CountdownScreen onto the same
/// root Navigator through different code paths. Each had its own local guard,
/// so neither saw the other: with a panic-button countdown on screen, a quick
/// access trigger stacked a second countdown, whose native arm is rejected with
/// `activeSessionExists` and whose blocking failure dialog then covered the
/// real countdown's PIN-cancel pad.
///
/// Ownership is explicit so a stale release from one entry point can never
/// free a countdown another entry point is showing.
abstract final class PanicCountdownGuard {
  static Object? _owner;
  static final ValueNotifier<bool> _held = ValueNotifier<bool>(false);

  /// Whether some entry point currently holds a countdown open.
  static bool get isHeld => _owner != null;

  /// [isHeld] as a listenable, for surfaces that must not open ABOVE a live
  /// countdown (the resume lock, external links) and wait for it instead.
  static ValueListenable<bool> get held => _held;

  /// Completes once no countdown is held; immediately when none is. With
  /// [timeout] it also completes when that runs out, and leaves no listener
  /// behind either way.
  static Future<void> whenReleased({Duration? timeout}) {
    if (!isHeld) return Future<void>.value();
    final released = Completer<void>();
    Timer? limit;
    void listener() {
      if (isHeld) return;
      limit?.cancel();
      _held.removeListener(listener);
      if (!released.isCompleted) released.complete();
    }

    _held.addListener(listener);
    if (timeout != null) {
      limit = Timer(timeout, () {
        _held.removeListener(listener);
        if (!released.isCompleted) released.complete();
      });
    }
    return released.future;
  }

  /// Takes the guard for [owner]. False when another owner already holds it.
  static bool tryAcquire(Object owner) {
    if (_owner != null) return false;
    _owner = owner;
    _held.value = true;
    return true;
  }

  /// Frees the guard, but only for the owner that took it.
  static void release(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _held.value = false;
  }

  /// Opens a countdown route while holding the guard for [owner].
  ///
  /// Returns null WITHOUT calling [push] when another entry point already holds
  /// the guard. Otherwise the guard is held until the route's future completes
  /// -- pop, replacement and removal all complete it -- or [push] throws.
  static Future<T?>? open<T>(Object owner, Future<T?> Function() push) {
    if (!tryAcquire(owner)) return null;
    Future<T?>? route;
    try {
      route = push();
    } finally {
      // A push that throws never produces a route that could release later.
      if (route == null) release(owner);
    }
    return route.whenComplete(() => release(owner));
  }

  @visibleForTesting
  static void resetForTesting() {
    _owner = null;
    _held.value = false;
  }
}
