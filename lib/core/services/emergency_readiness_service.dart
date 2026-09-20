import 'dart:async';

import 'package:flutter/foundation.dart';

import 'emergency_platform_service.dart';
import 'local_logger_service.dart';

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
    if (nextState.reasonCode == 'platformBridgeMissing') {
      // criticalSafetyReady is already false here (an unavailable snapshot is
      // not `isKnown`), so the readiness card turns red on its own -- verified,
      // not assumed: ReadinessCard derives every chip from automaticCallReady /
      // backgroundAlertReady, both of which require isKnown.
      //
      // What was missing is any durable trace of WHY. Without it this case is
      // indistinguishable from a plain timeout, and the only other evidence is
      // a logcat line the user cannot read (audit A-005).
      await LocalLoggerService.instance.warningCode(
        LocalWarningCode.emergencyPlatformBridgeMissing,
      );
    }
    _lastState = nextState;
    notifyListeners();
    return nextState;
  }
}
