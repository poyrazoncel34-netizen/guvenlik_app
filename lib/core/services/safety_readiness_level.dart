import 'emergency_platform_service.dart';

/// The three states anything may say about emergency readiness (owner decision
/// OD-2, 2026-10-11).
///
/// This exists so that COPY and RUNTIME STATE cannot come from two different
/// places. Before it, the home card decided its own headline from a count of
/// red chips while the dispatch path decided separately from
/// [PlatformReadinessSnapshot.criticalSafetyReady]; a future edit to either one
/// could have widened "ready" on one surface without the other noticing. Every
/// surface now derives its words from this single verdict.
enum SafetyReadinessLevel {
  /// Everything the platform must supply for a protected session is in place.
  fullyReady,

  /// The app works, but at least one capability a protected session needs is
  /// missing -- most often Android's exact-alarm access on a clean Android 14+
  /// install. Never describe this as ready.
  limited,

  /// Readiness could not be established at all: the platform bridge is missing,
  /// the probe timed out, or the OS is unsupported. Distinct from [limited]
  /// because there is no step the user can take to fix it, so offering them one
  /// would be a lie.
  unavailable,
}

extension SafetyReadinessLevelOf on PlatformReadinessSnapshot? {
  /// The verdict for this snapshot, with a null snapshot meaning "not probed
  /// yet", which is [SafetyReadinessLevel.unavailable] rather than ready:
  /// nothing may claim readiness it has not measured.
  SafetyReadinessLevel get readinessLevel {
    final snapshot = this;
    if (snapshot == null || !snapshot.isKnown) {
      return SafetyReadinessLevel.unavailable;
    }
    if (!snapshot.supportedOs) {
      return SafetyReadinessLevel.unavailable;
    }
    return snapshot.criticalSafetyReady
        ? SafetyReadinessLevel.fullyReady
        : SafetyReadinessLevel.limited;
  }
}
