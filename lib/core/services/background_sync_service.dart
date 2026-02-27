import 'dart:async';
import 'package:flutter/foundation.dart';
import 'offline_queue_service.dart';

/// Background sync service — uygulama açıkken periyodik senkronizasyon.
/// `workmanager` paketi uyumsuzluk nedeniyle devre dışı bırakılmıştı.
/// Bu versiyon `dart:async` Timer.periodic kullanarak çalışır.
class BackgroundSyncService {
  static const String taskName = 'guvendeyim_background_sync';
  static const Duration _syncInterval = Duration(minutes: 5);

  static Timer? _periodicTimer;
  static bool _initialized = false;

  /// Servisi başlat — çift başlatmayı önler.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('BackgroundSync: Initialized');
  }

  /// Periyodik senkronizasyon timer'ını başlat.
  static Future<void> registerPeriodicSync() async {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_syncInterval, (_) async {
      await _performSync();
    });
    debugPrint(
      'BackgroundSync: Periodic sync registered (${_syncInterval.inMinutes}m interval)',
    );
  }

  /// Tek seferlik senkronizasyon çalıştır.
  static Future<void> syncNow() async {
    await _performSync();
  }

  /// Senkronizasyon mantığı.
  static Future<void> _performSync() async {
    debugPrint('BackgroundSync: Sync started');
    try {
      // 1) Offline queue'daki bekleyen event'leri senkronize et
      await OfflineQueueService.instance.syncPendingEvents();

      debugPrint('BackgroundSync: Sync completed');
    } catch (e) {
      debugPrint('BackgroundSync: Sync failed: $e');
    }
  }

  /// Tüm timer'ları iptal et.
  static Future<void> cancelAll() async {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _initialized = false;
    debugPrint('BackgroundSync: All timers cancelled');
  }
}

