import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The single invocation boundary between Dart and the native safety kernel.
///
/// Extracted from `emergency_platform_service.dart` (867 lines of accepted
/// debt) when audit A-005 added bridge detection to it: the file-size ratchet
/// refuses to let that file grow, and the project rule is to move logic into a
/// focused service rather than to delete comments until it fits.
///
/// Everything here is one concern -- turning a platform call into a typed,
/// never-throwing outcome -- and it is the only place that decides what each
/// failure MEANS. Keeping that decision in one class is why the distinction
/// below could be added in one edit instead of four.
class EmergencyPlatformChannel {
  EmergencyPlatformChannel(this._channel, {required Duration defaultTimeout})
    : _defaultTimeout = defaultTimeout;

  final MethodChannel _channel;
  final Duration _defaultTimeout;

  bool _bridgeMissing = false;

  /// True once an invocation proved the native handler is not registered.
  ///
  /// Latched, never cleared: a FlutterEngine configures its channels once, so
  /// an absent bridge does not reappear inside the process, and a safety
  /// signal must not flicker back to "fine" because a later call happened to
  /// time out instead.
  bool get bridgeMissing => _bridgeMissing;

  /// `MissingPluginException` is NOT `PlatformException`: the native side did
  /// not reject the call, it was never there to receive it. Collapsing the two
  /// is what let a countdown start with no native session behind it (A-005).
  String _classify(Object error, String method) {
    if (error is MissingPluginException) {
      _bridgeMissing = true;
      debugPrint('[EmergencyPlatform] $method: native bridge missing');
      return 'platformBridgeMissing';
    }
    if (error is TimeoutException) {
      debugPrint('[EmergencyPlatform] $method timed out');
      return 'timeout';
    }
    debugPrint('[EmergencyPlatform] $method failed');
    return error is PlatformException ? 'platformError' : 'unexpectedError';
  }

  Future<TypedInvocation> invokeTypedMap(
    String method, {
    Map<String, Object?>? arguments,
    Duration? timeout,
  }) async {
    try {
      final response = await _channel
          .invokeMethod<dynamic>(method, arguments)
          .timeout(timeout ?? _defaultTimeout);
      final mapped = toMap(response);
      if (mapped == null) {
        return const TypedInvocation.failed('malformedResponse');
      }
      return TypedInvocation.completed(mapped);
    } on Exception catch (error) {
      return TypedInvocation.failed(_classify(error, method));
    }
  }

  Future<Map<String, dynamic>> invokeMap(
    String method, {
    Map<String, Object?>? arguments,
    Duration? timeout,
  }) async {
    try {
      final response = await _channel
          .invokeMethod<dynamic>(method, arguments)
          .timeout(timeout ?? _defaultTimeout);
      return toMap(response) ?? const <String, dynamic>{};
    } on Exception catch (error) {
      _classify(error, method);
      return const <String, dynamic>{};
    }
  }

  Future<bool> invokeBool(
    String method, {
    Map<String, Object?>? arguments,
  }) async {
    try {
      return await _channel
              .invokeMethod<bool>(method, arguments)
              .timeout(_defaultTimeout) ??
          false;
    } on Exception catch (error) {
      _classify(error, method);
      return false;
    }
  }

  /// Fire-and-forget system-settings hand-off: it has no reply to classify,
  /// but a missing bridge still has to be recorded.
  Future<void> invokeVoid(String method, {Duration? timeout}) async {
    try {
      await _channel
          .invokeMethod<void>(method, null)
          .timeout(timeout ?? _defaultTimeout);
    } on Exception catch (error) {
      _classify(error, method);
    }
  }

  /// For replies that are not maps (the diagnostics list). Returns null on any
  /// failure; the caller decides what an absent reply means.
  Future<Object?> invokeRaw(String method, {Duration? timeout}) async {
    try {
      return await _channel
          .invokeMethod<dynamic>(method, null)
          .timeout(timeout ?? _defaultTimeout);
    } on Exception catch (error) {
      _classify(error, method);
      return null;
    }
  }

  /// Platform maps arrive as `Map<Object?, Object?>`; never trust the shape.
  static Map<String, dynamic>? toMap(dynamic event) {
    if (event is Map) {
      return event.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }
}

class TypedInvocation {
  const TypedInvocation.completed(this.value)
    : completed = true,
      reasonCode = '';

  const TypedInvocation.failed(this.reasonCode)
    : completed = false,
      value = const <String, dynamic>{};

  final bool completed;
  final Map<String, dynamic> value;
  final String reasonCode;
}
