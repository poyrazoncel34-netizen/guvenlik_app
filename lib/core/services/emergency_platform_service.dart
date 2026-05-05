import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'call_service.dart';
import 'check_in_expiry_coordinator.dart';

class EmergencyPlatformService {
  EmergencyPlatformService._();

  static final EmergencyPlatformService instance = EmergencyPlatformService._();

  static const MethodChannel _methodChannel = MethodChannel(
    'com.poyrazoncel.korubeni/emergency_platform',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.poyrazoncel.korubeni/emergency_platform/events',
  );

  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<dynamic>? _eventsSubscription;
  bool _initialized = false;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  Future<void> initialize() async {
    if (!isSupported || _initialized) {
      return;
    }

    _eventsSubscription = _eventChannel.receiveBroadcastStream().listen((
      dynamic event,
    ) {
      final mapped = _toMap(event);
      if (mapped != null) {
        _eventsController.add(mapped);
      }
    }, onError: _eventsController.addError);

    _initialized = true;
  }

  static const Duration _defaultTimeout = Duration(seconds: 5);
  static const Duration _dispatchTimeout = Duration(seconds: 5);

  Future<bool> scheduleCheckIn({
    String sessionId = CheckInExpiryCoordinator.checkInSession,
    required String phase,
    required DateTime deadline,
    Duration graceDuration = const Duration(seconds: 60),
  }) async {
    if (!isSupported) {
      return false;
    }
    final response = await _invokeMap(
      'scheduleCheckIn',
      arguments: <String, Object?>{
        'sessionId': sessionId,
        'phase': phase,
        'deadlineMs': deadline.millisecondsSinceEpoch,
        'graceDurationMs': graceDuration.inMilliseconds,
      },
    );
    return response['scheduled'] == true && response['exact'] == true;
  }

  Future<void> cancelCheckIn({
    String sessionId = CheckInExpiryCoordinator.checkInSession,
  }) async {
    if (!isSupported) {
      return;
    }
    try {
      await _methodChannel
          .invokeMethod<void>('cancelCheckIn', <String, Object?>{
            'sessionId': sessionId,
          })
          .timeout(_defaultTimeout);
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] cancelCheckIn timed out');
    } on PlatformException catch (e) {
      debugPrint('[EmergencyPlatform] cancelCheckIn failed: ${e.code}');
    } on Exception catch (e) {
      debugPrint('[EmergencyPlatform] cancelCheckIn unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>?> consumePendingTrigger() async {
    if (!isSupported) {
      return null;
    }
    return _invokeMap('consumePendingTrigger');
  }

  Future<Map<String, dynamic>> getDeviceState() async {
    if (!isSupported) {
      return const <String, dynamic>{};
    }
    return _invokeMap('getDeviceState');
  }

  Future<bool> canScheduleExactAlarms() async {
    if (!isSupported) {
      return false;
    }
    return await _invokeBool('canScheduleExactAlarms');
  }

  Future<void> requestExactAlarmPermission() async {
    if (!isSupported) {
      return;
    }
    try {
      await _methodChannel
          .invokeMethod<void>('requestExactAlarmPermission')
          .timeout(_defaultTimeout);
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] requestExactAlarmPermission timed out');
    } on PlatformException catch (e) {
      debugPrint(
        '[EmergencyPlatform] requestExactAlarmPermission failed: ${e.code}',
      );
    } on Exception catch (e) {
      debugPrint(
        '[EmergencyPlatform] requestExactAlarmPermission unexpected error: $e',
      );
    }
  }

  Future<bool> openManufacturerSettings() async {
    if (!isSupported) {
      return false;
    }
    return _invokeBool('openManufacturerSettings');
  }

  Future<EmergencyCallResult> executeEmergencyNative({
    required String primaryNumber,
  }) async {
    if (!isSupported) {
      return EmergencyCallResult.failed(primaryNumber);
    }
    final response = await _invokeMap(
      'executeEmergencyNative',
      arguments: <String, Object?>{'primaryNumber': primaryNumber},
      timeout: _dispatchTimeout,
    );
    final number = response['number'] as String? ?? primaryNumber;
    switch (response['status']) {
      case 'directCallStarted':
        return EmergencyCallResult.direct(number);
      case 'dialerOpened':
        return EmergencyCallResult.dialer(number);
      default:
        return EmergencyCallResult.failed(number);
    }
  }

  /// Schedule a native AlarmManager backup for the countdown timer.
  /// If the Dart Timer.periodic freezes under Doze, this alarm fires and
  /// executes the emergency natively via EmergencyExecutor.
  Future<bool> scheduleCountdownAlarm({
    required DateTime deadline,
    required String primaryNumber,
    required String dispatchId,
  }) async {
    if (!isSupported) return false;
    final response = await _invokeMap(
      'scheduleCountdownAlarm',
      arguments: {
        'deadlineMs': deadline.millisecondsSinceEpoch,
        'primaryNumber': primaryNumber,
        'dispatchId': dispatchId,
      },
    );
    return response['scheduled'] == true;
  }

  /// Cancel the countdown backup alarm (user entered correct PIN).
  Future<void> cancelCountdownAlarm({String? dispatchId}) async {
    if (!isSupported) return;
    try {
      await _methodChannel
          .invokeMethod<void>('cancelCountdownAlarm', <String, Object?>{
            'dispatchId': dispatchId,
          })
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] cancelCountdownAlarm timed out');
    } on PlatformException catch (e) {
      debugPrint('[EmergencyPlatform] cancelCountdownAlarm failed: ${e.code}');
    } on Exception catch (e) {
      // Catches MissingPluginException and any other unexpected exception types.
      // cancelCountdownAlarm is cleanup-only; it must NEVER propagate to the
      // dispatch caller and kill _executeEmergency().
      debugPrint(
        '[EmergencyPlatform] cancelCountdownAlarm unexpected error: $e',
      );
    }
  }

  /// Check if the native alarm already fired (Dart timer was frozen).
  /// Used to prevent double-execution when the Dart side resumes.
  Future<bool> didCountdownAlarmFire({required String dispatchId}) async {
    if (!isSupported) return false;
    return _invokeBool(
      'didCountdownAlarmFire',
      arguments: <String, Object?>{'dispatchId': dispatchId},
    );
  }

  Future<Map<String, dynamic>> _invokeMap(
    String method, {
    Map<String, Object?>? arguments,
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      final response = await _methodChannel
          .invokeMethod<dynamic>(method, arguments)
          .timeout(timeout);
      return _toMap(response) ?? const <String, dynamic>{};
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] $method timed out');
      return const <String, dynamic>{};
    } on PlatformException catch (e) {
      debugPrint('[EmergencyPlatform] $method failed: ${e.code}');
      return const <String, dynamic>{};
    } on Exception catch (e) {
      debugPrint('[EmergencyPlatform] $method unexpected error: $e');
      return const <String, dynamic>{};
    }
  }

  Future<bool> _invokeBool(
    String method, {
    Map<String, Object?>? arguments,
  }) async {
    try {
      return await _methodChannel
              .invokeMethod<bool>(method, arguments)
              .timeout(_defaultTimeout) ??
          false;
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] $method timed out');
      return false;
    } on PlatformException catch (e) {
      debugPrint('[EmergencyPlatform] $method failed: ${e.code}');
      return false;
    } on Exception catch (e) {
      debugPrint('[EmergencyPlatform] $method unexpected error: $e');
      return false;
    }
  }

  Map<String, dynamic>? _toMap(dynamic event) {
    if (event is Map) {
      return event.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  Future<void> dispose() async {
    await _eventsSubscription?.cancel();
    await _eventsController.close();
  }
}
