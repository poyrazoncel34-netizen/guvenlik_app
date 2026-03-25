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

  Future<Map<String, dynamic>> sendSms({
    required List<String> recipients,
    required String message,
  }) async {
    if (!isSupported) {
      return const <String, dynamic>{};
    }
    final response = await _methodChannel.invokeMethod<dynamic>('sendSms', {
      'recipients': recipients,
      'message': message,
    });
    return _toMap(response) ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> triggerEmergency({
    required List<String> recipients,
    required String message,
    required String primaryNumber,
  }) async {
    if (!isSupported) {
      return const <String, dynamic>{};
    }
    final response = await _methodChannel.invokeMethod<dynamic>(
      'triggerEmergency',
      {
        'recipients': recipients,
        'message': message,
        'primaryNumber': primaryNumber,
      },
    );
    return _toMap(response) ?? const <String, dynamic>{};
  }

  Future<void> startRecordingSession() async {
    if (!isSupported) {
      return;
    }
    // KVKK m.5 + TCK m.133: Ses kaydı rızası kontrolü
    if (!ConsentGateService.isAudioAllowed()) {
      debugPrint('[EmergencyPlatform] Ses kaydı rızası verilmemiş — kayıt başlatılmadı');
      return;
    }
    await _methodChannel.invokeMethod<void>('startRecordingSession');
  }

  Future<void> stopRecordingSession() async {
    if (!isSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('stopRecordingSession');
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
