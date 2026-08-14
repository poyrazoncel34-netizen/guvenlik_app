import 'package:easy_localization/easy_localization.dart';

import '../../domain/models/activity_event.dart';
import 'activity_service.dart';
import 'dispatch_outcome.dart';
import 'emergency_dispatch_pipeline.dart';
import 'haptic_service.dart';
import 'notification_service.dart';
import 'offline_queue_service.dart';

/// The non-critical targets a panic dispatch fans out to, as labelled steps.
///
/// Extracted from `CountdownScreen`, which the size ratchet holds as accepted
/// debt and which the repo's own patterns file names as the counter-example for
/// "critical logic inside a StatefulWidget". Keeping the list here also means
/// the set of targets is readable in one place: adding a target without giving
/// it a [DispatchTarget] is not possible.
abstract final class EmergencyBookkeeping {
  static List<BestEffortStep> panicSteps({
    required String eventTitle,
    required String eventDescription,
    required String alertTitle,
    required String alertBody,
    required int notificationId,
  }) => <BestEffortStep>[
    BestEffortStep.effect(
      target: DispatchTarget.offlineQueue,
      run: () => OfflineQueueService.instance.enqueue(
        OfflineEvent(
          type: 'emergency',
          title: eventTitle,
          description: eventDescription,
          data: const <String, dynamic>{},
        ),
      ),
    ),
    BestEffortStep.effect(
      target: DispatchTarget.safetyTimeline,
      run: () => ActivityService.logEvent(
        type: ActivityType.emergencyTriggered,
        title: eventTitle,
        description: eventDescription,
      ),
    ),
    BestEffortStep.effect(
      target: DispatchTarget.haptic,
      run: HapticService.emergencyTriggered,
    ),
    // The only step that reports a richer outcome than "done or threw": a
    // notification the user switched off, or one the OS will not display, is
    // neither a success nor an exception.
    BestEffortStep(
      target: DispatchTarget.alertNotification,
      run: () => NotificationService.instance.showEmergencyAlert(
        id: notificationId,
        title: alertTitle,
        body: alertBody,
      ),
    ),
  ];

  /// The panic path's step list with this app's copy already resolved.
  static List<BestEffortStep> panicStepsWithDefaultCopy() => panicSteps(
    eventTitle: 'countdown_emergency_title'.tr(),
    eventDescription: 'countdown_emergency_desc'.tr(),
    alertTitle: 'countdown_emergency_title'.tr(),
    alertBody: 'alarm_notification_body'.tr(),
    notificationId: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
}
