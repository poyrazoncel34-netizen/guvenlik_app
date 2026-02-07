import 'package:flutter/foundation.dart';

/// Background sync service - workmanager paketi uyumsuzluk sorunu nedeniyle gecici olarak devre disi
/// Firebase zaten aktif oldugu icin kritik degil
class BackgroundSyncService {
  static const String taskName = 'guvendeyim_background_sync';

  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    debugPrint('BackgroundSync: Workmanager disabled due to compatibility issues');
  }

  static Future<void> initialize() async {
    debugPrint('BackgroundSync: Initialize skipped - workmanager disabled');
  }

  static Future<void> registerPeriodicSync() async {
    debugPrint('BackgroundSync: Register skipped - workmanager disabled');
  }

  static Future<void> cancelAll() async {
    debugPrint('BackgroundSync: Cancel skipped - workmanager disabled');
  }
}
