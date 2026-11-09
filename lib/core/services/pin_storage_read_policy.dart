import 'emergency_session_contract.dart';
import 'pin_verification_service.dart';

/// How a bounded, backed-off read of the PIN record ended.
enum PinStorageVerdict {
  /// The store answered cleanly: a PIN is configured, or provably absent.
  readable,

  /// Every attempt failed, and at least one of them by timing out. A slow
  /// keystore (cold start, first access after an update that migrates the
  /// store) is not evidence of corruption, so the user is told to retry.
  transientFailure,

  /// Every attempt failed with a storage error. The record cannot be
  /// decrypted and is unlikely to recover on its own.
  persistentFailure,
}

class PinStorageReadResult {
  const PinStorageReadResult({
    required this.verdict,
    required this.state,
    required this.attempts,
  });

  final PinStorageVerdict verdict;
  final PinState state;
  final int attempts;
}

typedef PinStorageDelay = Future<void> Function(Duration duration);

/// Separates a transient secure-storage failure from a persistent one before
/// the critical bootstrap gives up on the PIN record.
///
/// SECURITY: this policy only READS. It never writes, deletes or resets the
/// PIN record and never turns a failure into [PinState.absent] -- that would
/// open PIN setup to someone who does not know the PIN. The only way past a
/// persistent failure stays the typed-confirmation full local wipe, the same
/// policy as "PIN'imi unuttum".
class PinStorageReadPolicy {
  const PinStorageReadPolicy({
    required this.pins,
    this.backoff = defaultBackoff,
    this.delay = _realDelay,
  });

  /// Pauses between attempts: 3 attempts in total. When the keystore read
  /// itself is slow, each attempt is bounded by one
  /// [PinVerificationService.defaultOperationTimeout], so all three attempts
  /// fit inside [pinStepBudget] (about 7.2 s).
  ///
  /// The one-time legacy migration path can chain up to four bounded
  /// operations in a single attempt. If that exhausts [pinStepBudget], the
  /// bootstrap's own timeout ends the step as `pinTimeout` after fewer
  /// attempts -- still bounded, still fail-closed, still the recovery screen.
  static const List<Duration> defaultBackoff = <Duration>[
    Duration(milliseconds: 300),
    Duration(milliseconds: 900),
  ];

  /// Bootstrap timeout for the step that runs this policy.
  static const Duration pinStepBudget = Duration(seconds: 10);

  final PinVerificationService pins;
  final List<Duration> backoff;
  final PinStorageDelay delay;

  int get maxAttempts => backoff.length + 1;

  Future<PinStorageReadResult> read() async {
    var sawTimeout = false;
    for (var attempt = 1; ; attempt++) {
      final state = await pins.loadState();
      if (state == PinState.configured || state == PinState.absent) {
        return PinStorageReadResult(
          verdict: PinStorageVerdict.readable,
          state: state,
          attempts: attempt,
        );
      }
      if (pins.lastReadFailure != PinReadFailure.storageError) {
        sawTimeout = true;
      }
      if (attempt >= maxAttempts) {
        return PinStorageReadResult(
          verdict: sawTimeout
              ? PinStorageVerdict.transientFailure
              : PinStorageVerdict.persistentFailure,
          state: state,
          attempts: attempt,
        );
      }
      await delay(backoff[attempt - 1]);
    }
  }

  static Future<void> _realDelay(Duration duration) =>
      Future<void>.delayed(duration);
}
