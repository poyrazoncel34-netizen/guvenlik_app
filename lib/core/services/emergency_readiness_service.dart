import 'dart:async';

import 'package:flutter/foundation.dart';

import 'emergency_platform_service.dart';

/// System 3A: Checks device readiness for emergency dispatch.
/// Non-blocking — results cached for later query.
class EmergencyReadinessService extends ChangeNotifier {
  EmergencyReadinessService._({
    EmergencyPlatformService? platformService,
    Duration timeout = const Duration(seconds: 3),
  }) : _platformService = platformService ?? EmergencyPlatformService.instance,
       _timeout = timeout;

  factory EmergencyReadinessService.forTesting({
    required EmergencyPlatformService platformService,
    Duration timeout = const Duration(milliseconds: 100),
  }) => EmergencyReadinessService._(
    platformService: platformService,
    timeout: timeout,
  );

  static final EmergencyReadinessService instance =
      EmergencyReadinessService._();

  final EmergencyPlatformService _platformService;
  final Duration _timeout;
  int _latestProbeId = 0;
  PlatformReadinessSnapshot? _lastState;

  PlatformReadinessSnapshot? get lastState => _lastState;

  bool get isReady => _lastState?.criticalSafetyReady ?? false;

  Future<PlatformReadinessSnapshot> checkReadiness() async {
    final probeId = ++_latestProbeId;
    PlatformReadinessSnapshot nextState;
    try {
      nextState = await _platformService.getPlatformReadiness().timeout(
        _timeout,
      );
    } on TimeoutException {
      debugPrint('[EmergencyReadiness] checkReadiness timed out');
      nextState = const PlatformReadinessSnapshot.unavailable(
        reasonCode: 'timeout',
      );
    } catch (e) {
      debugPrint('[EmergencyReadiness] checkReadiness failed: $e');
      nextState = const PlatformReadinessSnapshot.unavailable(
        reasonCode: 'unexpectedError',
      );
    }
    if (probeId != _latestProbeId) {
      return _lastState ??
          const PlatformReadinessSnapshot.unavailable(reasonCode: 'superseded');
    }
    _lastState = nextState;
    notifyListeners();
    return nextState;
  }
}
