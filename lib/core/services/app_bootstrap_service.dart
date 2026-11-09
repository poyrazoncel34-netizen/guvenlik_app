import 'dart:async';

import '../di/service_locator.dart';
import 'contact_service.dart';
import 'data_migration_service.dart';
import 'pin_storage_read_policy.dart';
import 'pin_verification_service.dart';

typedef CriticalBootstrapOperation = Future<void> Function();

class CriticalBootstrapStep {
  CriticalBootstrapStep(this.id, this.operation, {this.timeout})
    : assert(RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(id));

  final String id;
  final CriticalBootstrapOperation operation;

  /// Overrides [AppBootstrapService.timeout] for this step only. Used by a
  /// step that retries internally and therefore needs a larger, still bounded
  /// budget.
  final Duration? timeout;
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

  factory AppBootstrapService.production({
    List<CriticalBootstrapStep> preliminarySteps = const [],
  }) => AppBootstrapService(
    criticalSteps: <CriticalBootstrapStep>[
      ...preliminarySteps,
      CriticalBootstrapStep('di', setupServiceLocator),
      CriticalBootstrapStep('migration', DataMigrationService.migrate),
      pinStorageStep(),
      CriticalBootstrapStep('contact', ContactService.warmUpRequired),
    ],
  );

  final List<CriticalBootstrapStep> _criticalSteps;
  final Duration timeout;

  Future<CriticalBootstrapResult> initializeCritical() async {
    for (final step in _criticalSteps) {
      try {
        await step.operation().timeout(step.timeout ?? timeout);
      } on TimeoutException {
        return CriticalBootstrapResult.failed('${step.id}Timeout');
      } catch (_) {
        return CriticalBootstrapResult.failed('${step.id}Failed');
      }
    }
    return const CriticalBootstrapResult.ready();
  }

  /// Reason codes of the secure-storage steps. Both read the same
  /// keystore-backed store, so both get the recovery surface (retry, or the
  /// typed-confirmation full wipe) instead of the exit-less fatal widget.
  static const Set<String> _localRecoveryReasons = <String>{
    'pinFailed',
    'pinTimeout',
    'contactFailed',
    'contactTimeout',
  };

  /// Whether a failed critical bootstrap may be shown the local recovery
  /// surface. Every other reason code falls through to the generic fatal
  /// error widget.
  static bool offersLocalRecovery(String reasonCode) =>
      _localRecoveryReasons.contains(reasonCode);

  /// The critical PIN-storage probe. [pins] and [backoff] are injectable for
  /// tests only; production reads through [PinVerificationService.instance].
  ///
  /// The step's reason code carries the policy's verdict: a transient failure
  /// (some attempt timed out) surfaces as `pinTimeout`, a persistent one
  /// (every attempt was a storage error) as `pinFailed`. The recovery screen
  /// words its explanation from that code.
  static CriticalBootstrapStep pinStorageStep({
    PinVerificationService? pins,
    List<Duration> backoff = PinStorageReadPolicy.defaultBackoff,
  }) {
    return CriticalBootstrapStep('pin', () async {
      final result = await PinStorageReadPolicy(
        pins: pins ?? PinVerificationService.instance,
        backoff: backoff,
      ).read();
      switch (result.verdict) {
        case PinStorageVerdict.readable:
          return;
        case PinStorageVerdict.transientFailure:
          throw TimeoutException('PIN_STORAGE_SLOW');
        case PinStorageVerdict.persistentFailure:
          throw StateError('PIN_STORAGE_UNAVAILABLE');
      }
    }, timeout: PinStorageReadPolicy.pinStepBudget);
  }
}
