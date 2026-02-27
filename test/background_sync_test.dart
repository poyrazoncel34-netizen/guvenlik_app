import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/background_sync_service.dart';

void main() {
  group('BackgroundSyncService', () {
    tearDown(() async {
      await BackgroundSyncService.cancelAll();
    });

    test('initialize can be called multiple times safely', () async {
      await BackgroundSyncService.initialize();
      await BackgroundSyncService.initialize(); // second call should be no-op
      // No exception means it passed
    });

    test('registerPeriodicSync starts without error', () async {
      await BackgroundSyncService.initialize();
      await BackgroundSyncService.registerPeriodicSync();
      // No exception means it passed
    });

    test('cancelAll stops timers and resets state', () async {
      await BackgroundSyncService.initialize();
      await BackgroundSyncService.registerPeriodicSync();
      await BackgroundSyncService.cancelAll();
      // After cancel, initialize can be called again
      await BackgroundSyncService.initialize();
      // No exception means the state was properly reset
    });

    test('syncNow runs without error', () async {
      await BackgroundSyncService.initialize();
      await BackgroundSyncService.syncNow();
      // No exception means it passed
    });

    test('cancelAll is idempotent', () async {
      await BackgroundSyncService.cancelAll();
      await BackgroundSyncService.cancelAll();
      // No exception means it passed
    });

    test('taskName is defined', () {
      expect(BackgroundSyncService.taskName, isNotEmpty);
    });
  });
}
