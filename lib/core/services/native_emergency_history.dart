import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/activity_event.dart';
import 'activity_service.dart';
import 'emergency_platform_service.dart';
import 'emergency_session_contract.dart';

/// Projects durable native outcomes without dispatching or resolving contacts.
abstract final class NativeEmergencyHistory {
  static String eventId(SessionToken token) =>
      'native:${token.protocolVersion}:${token.kind.wireName}:${token.randomId}:${token.generation}';

  static Future<void> record(SessionSnapshot snapshot) async {
    final token = snapshot.token;
    if (!snapshot.isPresent ||
        token == null ||
        !snapshot.lifecycleState.isTerminal ||
        snapshot.lifecycleState == EmergencySessionLifecycle.cancelled ||
        snapshot.lifecycleState == EmergencySessionLifecycle.corrupted) {
      return;
    }
    final callKey = switch (snapshot.callRequestOutcome) {
      CallRequestOutcome.submittedUnconfirmed =>
        'native_history_request_submitted',
      CallRequestOutcome.failed => 'native_history_request_failed',
      CallRequestOutcome.notAttempted => 'native_history_request_unknown',
    };
    final fallbackKey = switch (snapshot.fallbackOutcome) {
      FallbackOutcome.posted => 'native_history_fallback_posted',
      FallbackOutcome.failed => 'native_history_fallback_failed',
      FallbackOutcome.expired => 'native_history_fallback_expired',
      FallbackOutcome.notAttempted => null,
    };
    final warningKey = _warningKey(token.kind, snapshot.graceWarningOutcome);
    await ActivityService.logEvent(
      eventId: eventId(token),
      timestamp: snapshot.completedAt,
      type: ActivityType.emergencyTriggered,
      title: 'countdown_emergency_title'.tr(),
      description: [
        callKey.tr(),
        if (fallbackKey != null) fallbackKey.tr(),
        if (warningKey != null) warningKey.tr(),
        if (snapshot.completedAt == null) 'native_history_recorded_time'.tr(),
      ].join(' '),
    );
  }

  /// Why the Check-In / Safe Walk final warning was not shown (A-03, owner
  /// decision 2026-10-09). The warning is best effort and never moves the
  /// final deadline; the timeline says when it did not reach the user.
  static String? _warningKey(EmergencySessionKind kind, String? outcome) {
    if (kind == EmergencySessionKind.panic) return null;
    return switch (outcome) {
      'failed' => 'native_history_warning_failed',
      'notAttempted' => 'native_history_warning_missed',
      'unknown' => 'native_history_warning_unknown',
      _ => null,
    };
  }

  /// Whether the translation catalogue is loaded.
  ///
  /// The record is written as translated TEXT. EmergencyTriggerHost sits above
  /// MaterialApp and reconciles at cold start, before MaterialApp's delegate
  /// has loaded the catalogue; `.tr()` then returns the key itself and the
  /// timeline kept `countdown_emergency_title` / `native_history_request_*`
  /// for good (reproduced on an API 35 emulator). Until the catalogue exists
  /// the outcome stays in the native journal, unacknowledged.
  @visibleForTesting
  static bool Function() translationsReady = _catalogueLoaded;

  static bool _catalogueLoaded() => trExists('countdown_emergency_title');

  static Future<void> reconcilePending(
    EmergencyPlatformService platform,
  ) async {
    final outcomes = await platform.pendingEmergencyOutcomes();
    if (outcomes.isEmpty || !translationsReady()) return;
    for (final snapshot in outcomes) {
      if (!snapshot.isPresent ||
          snapshot.token == null ||
          !snapshot.lifecycleState.isTerminal) {
        continue;
      }
      await record(snapshot);
      await platform.acknowledgeEmergencyOutcome(snapshot.token!);
    }
  }

  /// Cold-start entry: waits, bounded, for the catalogue, then reconciles.
  /// Timer-based on purpose -- no frame is guaranteed while starting up. If
  /// the catalogue never appears the outcomes simply stay pending for the
  /// next resume or dispatch event.
  static Future<void> reconcileWhenReady(
    EmergencyPlatformService platform, {
    Duration pollInterval = const Duration(milliseconds: 100),
    int maxPolls = 50,
  }) async {
    for (var poll = 0; poll < maxPolls && !translationsReady(); poll++) {
      await Future<void>.delayed(pollInterval);
    }
    await reconcilePending(platform);
  }
}
