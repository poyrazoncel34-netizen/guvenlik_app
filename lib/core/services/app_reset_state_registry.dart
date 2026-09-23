import 'dart:async';

typedef AppResetStateCallback = FutureOr<void> Function();

/// Process-local state that mirrors deleted storage registers here.
///
/// Storage deletion alone is insufficient while providers live above the
/// navigator for the lifetime of the process. A successful reset awaits every
/// registered invalidation before it may report completion.
class AppResetStateRegistry {
  AppResetStateRegistry._();

  static final Map<Object, AppResetStateCallback> _callbacks =
      <Object, AppResetStateCallback>{};

  static void register(Object owner, AppResetStateCallback callback) {
    _callbacks[owner] = callback;
  }

  static void unregister(Object owner) {
    _callbacks.remove(owner);
  }

  static Future<bool> resetAll() async {
    var completed = true;
    for (final callback in List<AppResetStateCallback>.from(
      _callbacks.values,
    )) {
      try {
        await callback();
      } catch (_) {
        completed = false;
      }
    }
    return completed;
  }
}
