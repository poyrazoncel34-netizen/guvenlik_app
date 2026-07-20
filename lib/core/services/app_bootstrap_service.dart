import 'dart:async';

import '../di/service_locator.dart';
import 'contact_service.dart';
import 'data_migration_service.dart';
import 'emergency_session_contract.dart';
import 'pin_verification_service.dart';

typedef CriticalBootstrapOperation = Future<void> Function();

class CriticalBootstrapStep {
  CriticalBootstrapStep(this.id, this.operation)
    : assert(RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(id));

  final String id;
  final CriticalBootstrapOperation operation;
}

class CriticalBootstrapResult {
  const CriticalBootstrapResult._({required this.isReady, this.reasonCode});

  const CriticalBootstrapResult.ready()
    : this._(isReady: true, reasonCode: null);

  const CriticalBootstrapResult.failed(String reasonCode)
    : this._(isReady: false, reasonCode: reasonCode);

  final bool isReady;
  final String? reasonCode;
}

/// Runs only the startup work required before the home screen may claim that
/// safety features are available. Each step is sequential, bounded and
/// fail-closed; raw exceptions never cross this boundary.
class AppBootstrapService {
  AppBootstrapService({
    required List<CriticalBootstrapStep> criticalSteps,
    this.timeout = const Duration(seconds: 5),
  }) : _criticalSteps = List<CriticalBootstrapStep>.unmodifiable(criticalSteps);

  factory AppBootstrapService.production() => AppBootstrapService(
    criticalSteps: <CriticalBootstrapStep>[
      CriticalBootstrapStep('di', setupServiceLocator),
      CriticalBootstrapStep('migration', DataMigrationService.migrate),
      CriticalBootstrapStep('pin', _verifyPinStorageReadable),
      CriticalBootstrapStep('contact', ContactService.warmUpRequired),
    ],
  );

  final List<CriticalBootstrapStep> _criticalSteps;
  final Duration timeout;

  Future<CriticalBootstrapResult> initializeCritical() async {
    for (final step in _criticalSteps) {
      try {
        await step.operation().timeout(timeout);
      } on TimeoutException {
        return CriticalBootstrapResult.failed('${step.id}Timeout');
      } catch (_) {
        return CriticalBootstrapResult.failed('${step.id}Failed');
      }
    }
    return const CriticalBootstrapResult.ready();
  }

  static Future<void> _verifyPinStorageReadable() async {
    final state = await PinVerificationService.instance.loadState();
    if (state == PinState.loading || state == PinState.readFailed) {
      throw StateError('PIN_STORAGE_UNAVAILABLE');
    }
  }
}
