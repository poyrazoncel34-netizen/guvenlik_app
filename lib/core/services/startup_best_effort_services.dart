import 'atomic_storage_service.dart';
import 'connectivity_service.dart';
import 'foreground_service.dart';
import 'haptic_service.dart';
import 'local_logger_service.dart';
import 'medical_data_cleanup_service.dart';
import 'notification_service.dart';
import 'offline_queue_service.dart';
import 'profile_email_cleanup_service.dart';
import 'sensitive_temp_file_service.dart';

/// The optional work `main()` hands to [initializeBestEffortServices] once the
/// critical bootstrap has succeeded.
///
/// Lives outside main.dart so tests can run the exact list the app runs,
/// instead of grepping main.dart for a name.
List<Future<void> Function()> buildStartupBestEffortServices({
  required bool isWeb,
}) {
  final services = <Future<void> Function()>[
    // KVKK Md.7 — purge orphaned medical-profile data from removed feature.
    // Best-effort (internally try/catch); runs concurrently so it never
    // blocks the emergency / notification startup path.
    MedicalDataCleanupService.purgeIfNeeded,
    // A-014 — delete the legacy profile e-mail without waiting for the user
    // to open a profile screen.
    ProfileEmailCleanupService.purgeIfNeeded,
    OfflineQueueService.instance.initialize,
    AtomicStorageService.instance.checkIntegrity,
    HapticService.initialize,
    ConnectivityService.instance.initialize,
    LocalLoggerService.instance.initialize,
    SensitiveTempFileService.purgeStaleExports,
  ];
  // Web skips platform notification plugins.
  if (!isWeb) {
    services.add(NotificationService.instance.initialize);
    services.add(KoruBeniForegroundService.configure);
  }
  return services;
}
