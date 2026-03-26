// ============================================================================
// FOREGROUND SERVICE — Arka Plan Koruma Servisi
// ============================================================================
// Android'de uygulama arka plana düştüğünde öldürülmesini engeller.
// Alarm/takip modu aktifken bildirim çubuğunda kalıcı bildirim gösterir.
// ============================================================================

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Foreground service notification channel ID
const String kForegroundChannelId = 'korubeni_foreground';
const String kForegroundChannelName = 'KoruBeni Arka Plan Servisi';
const int kForegroundNotificationId = 7777;

/// KoruBeni Foreground Service
///
/// Alarm modu veya takip modu aktifken arka planda çalışmaya devam etmeyi sağlar.
/// - Bildirim çubuğunda "KoruBeni Aktif" bildirimi gösterir
/// - GPS ve SMS fonksiyonlarının arka planda çalışmasını garanti eder
class KoruBeniForegroundService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _isConfigured = false;

  /// Servisi yapılandır — uygulama başlangıcında bir kez çağır.
  static Future<void> configure() async {
    if (kIsWeb) return;
    if (_isConfigured) return;

    try {
      // Bildirim kanalı oluştur
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        kForegroundChannelId,
        kForegroundChannelName,
        description: 'KoruBeni güvenlik servisi arka planda çalışıyor',
        importance: Importance.low, // Sessiz ama kalıcı bildirim
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          autoStart: false, // Manuel başlatma — sadece alarm modunda
          isForegroundMode: true,
          notificationChannelId: kForegroundChannelId,
          initialNotificationTitle: 'KoruBeni Aktif',
          initialNotificationContent: 'Acil durum modu aktif — konum paylaşılıyor',
          foregroundServiceNotificationId: kForegroundNotificationId,
          foregroundServiceTypes: [AndroidForegroundType.specialUse],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
      );

      _isConfigured = true;
      debugPrint('ForegroundService: Configured');
    } catch (e) {
      debugPrint('ForegroundService: Configure failed: $e');
    }
  }

  /// Foreground service'i başlat (alarm modu aktifleştiğinde çağır)
  static Future<void> start() async {
    if (kIsWeb) return;
    try {
      if (!_isConfigured) await configure();

      final isRunning = await _service.isRunning();
      if (isRunning) {
        debugPrint('ForegroundService: Already running');
        return;
      }

      await _service.startService();
      debugPrint('ForegroundService: Started');
    } catch (e) {
      debugPrint('ForegroundService: Start failed: $e');
    }
  }

  /// Foreground service'i durdur (alarm modu kapatıldığında çağır)
  static Future<void> stop() async {
    if (kIsWeb) return;
    try {
      final isRunning = await _service.isRunning();
      if (!isRunning) {
        debugPrint('ForegroundService: Already stopped');
        return;
      }

      _service.invoke('stop');
      debugPrint('ForegroundService: Stopped');
    } catch (e) {
      debugPrint('ForegroundService: Stop failed: $e');
    }
  }

  /// Servis çalışıyor mu?
  static Future<bool> isRunning() async {
    if (kIsWeb) return false;
    try {
      return await _service.isRunning();
    } catch (_) {
      return false;
    }
  }

  /// Bildirim metnini güncelle
  static void updateNotification(String title, String content) {
    if (kIsWeb) return;
    try {
      _service.invoke('updateNotification', {
        'title': title,
        'content': content,
      });
    } catch (e) {
      debugPrint('ForegroundService: Update notification failed: $e');
    }
  }
}

// ============================================================================
// İZOLE EDİLMİŞ ARKA PLAN KODU (ayrı Dart isolate'ta çalışır)
// ============================================================================

/// Top-level function — background isolate'ta çalışır
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  try {
    await notificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_bg_service_small'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  } catch (_) {
    // Best effort only.
  }

  Timer? heartbeatTimer;

  // "stop" komutu geldiğinde servisi durdur
  service.on('stop').listen((_) async {
    heartbeatTimer?.cancel();
    await service.stopSelf();
    debugPrint('ForegroundService: Stopped via command');
  });

  // Bildirim güncelleme komutu
  service.on('updateNotification').listen((event) {
    if (event != null && service is AndroidServiceInstance) {
      notificationsPlugin.show(
        kForegroundNotificationId,
        event['title'] as String? ?? 'KoruBeni',
        event['content'] as String? ?? 'Güvenlik modu aktif 🛡️',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            kForegroundChannelId,
            kForegroundChannelName,
            icon: 'ic_bg_service_small',
            ongoing: true,
            autoCancel: false,
          ),
        ),
      );
    }
  });

  // Periyodik "yaşıyorum" sinyali — her 30 saniyede bildirim güncelle
  heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
    try {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          await notificationsPlugin.show(
            kForegroundNotificationId,
            'KoruBeni Aktif',
            'Acil durum modu aktif — konum paylaşılıyor',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                kForegroundChannelId,
                kForegroundChannelName,
                icon: 'ic_bg_service_small',
                ongoing: true,
                autoCancel: false,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('ForegroundService: Heartbeat failed: \$e');
    }
  });

  debugPrint('ForegroundService: onStart executed in background isolate');
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
