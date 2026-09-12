import 'package:easy_localization/easy_localization.dart';
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
    await ActivityService.logEvent(
      eventId: eventId(token),
      timestamp: snapshot.completedAt,
      type: ActivityType.emergencyTriggered,
      title: 'countdown_emergency_title'.tr(),
      description: [
        callKey.tr(),
        if (fallbackKey != null) fallbackKey.tr(),
        if (snapshot.completedAt == null) 'native_history_recorded_time'.tr(),
      ].join(' '),
    );
  }

  static Future<void> reconcilePending(
    EmergencyPlatformService platform,
  ) async {
    for (final snapshot in await platform.pendingEmergencyOutcomes()) {
      if (!snapshot.isPresent ||
          snapshot.token == null ||
          !snapshot.lifecycleState.isTerminal) {
        continue;
      }
      await record(snapshot);
      await platform.acknowledgeEmergencyOutcome(snapshot.token!);
    }
  }
}
