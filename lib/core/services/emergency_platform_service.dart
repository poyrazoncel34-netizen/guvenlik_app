import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'consent_gate_service.dart';

class EmergencyPlatformService {
  EmergencyPlatformService._();

  static final EmergencyPlatformService instance = EmergencyPlatformService._();

  static const MethodChannel _methodChannel = MethodChannel(
    'com.poyrazoncel.korubeni/emergency_platform',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.poyrazoncel.korubeni/emergency_platform/events',
  );
  static const EventChannel _phoneStateChannel = EventChannel(
    'com.poyrazoncel.korubeni/emergency_platform/phone_state',
  );

  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _phoneStateController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<dynamic>? _eventsSubscription;
  StreamSubscription<dynamic>? _phoneStateSubscription;
  bool _initialized = false;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<Map<String, dynamic>> get events => _eventsController.stream;
  Stream<Map<String, dynamic>> get phoneStates => _phoneStateController.stream;

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

    _phoneStateSubscription = _phoneStateChannel
        .receiveBroadcastStream()
        .listen((dynamic event) {
          final mapped = _toMap(event);
          if (mapped != null) {
            _phoneStateController.add(mapped);
          }
        }, onError: _phoneStateController.addError);

    _initialized = true;
  }

  Future<void> scheduleCheckIn({
    required String phase,
    required DateTime deadline,
    Duration graceDuration = const Duration(seconds: 60),
  }) async {
    if (!isSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('scheduleCheckIn', {
      'phase': phase,
      'deadlineMs': deadline.millisecondsSinceEpoch,
      'graceDurationMs': graceDuration.inMilliseconds,
    });
  }

  Future<void> cancelCheckIn() async {
    if (!isSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('cancelCheckIn');
  }

  Future<Map<String, dynamic>?> consumePendingTrigger() async {
    if (!isSupported) {
      return null;
    }
    final response = await _methodChannel.invokeMethod<dynamic>(
      'consumePendingTrigger',
    );
    return _toMap(response);
  }

  Future<Map<String, dynamic>> getDeviceState() async {
    if (!isSupported) {
      return const <String, dynamic>{};
    }
    final response = await _methodChannel.invokeMethod<dynamic>(
      'getDeviceState',
    );
    return _toMap(response) ?? const <String, dynamic>{};
  }

  Future<bool> canScheduleExactAlarms() async {
    if (!isSupported) {
      return false;
    }
    return await _methodChannel.invokeMethod<bool>('canScheduleExactAlarms') ??
        false;
  }

  Future<void> requestExactAlarmPermission() async {
    if (!isSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('requestExactAlarmPermission');
  }

  Future<bool> openManufacturerSettings() async {
    if (!isSupported) {
      return false;
    }
    return await _methodChannel.invokeMethod<bool>(
          'openManufacturerSettings',
        ) ??
        false;
  }

  Future<void> executeEmergencyNative({
    required String primaryNumber,
  }) async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod<dynamic>(
        'executeEmergencyNative',
        {'primaryNumber': primaryNumber},
      ).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] executeEmergencyNative timed out');
    } catch (e) {
      debugPrint('[EmergencyPlatform] executeEmergencyNative failed: $e');
    }
  }

  /// Schedule a native AlarmManager backup for the countdown timer.
  /// If the Dart Timer.periodic freezes under Doze, this alarm fires and
  /// executes the emergency natively via EmergencyExecutor.
  Future<void> scheduleCountdownAlarm({
    required DateTime deadline,
    required String primaryNumber,
  }) async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod<void>('scheduleCountdownAlarm', {
        'deadlineMs': deadline.millisecondsSinceEpoch,
        'primaryNumber': primaryNumber,
      }).timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] scheduleCountdownAlarm timed out');
    }
  }

  /// Cancel the countdown backup alarm (user entered correct PIN).
  Future<void> cancelCountdownAlarm() async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod<void>('cancelCountdownAlarm')
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] cancelCountdownAlarm timed out');
    }
  }

  /// Check if the native alarm already fired (Dart timer was frozen).
  /// Used to prevent double-execution when the Dart side resumes.
  Future<bool> didCountdownAlarmFire() async {
    if (!isSupported) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('didCountdownAlarmFire') ?? false;
    } catch (e) {
      debugPrint('[EmergencyPlatform] didCountdownAlarmFire failed: $e');
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
    await _phoneStateSubscription?.cancel();
    await _eventsController.close();
    await _phoneStateController.close();
  }
}
