// ============================================================================
// FOREGROUND SERVICE — Background safety service
// ============================================================================
// Keeps the app alive when in the background while a critical safety flow is
// active. Localized notification copy is loaded via easy_localization in the
// main isolate and forwarded to the background isolate via SharedPreferences,
// because easy_localization is not initialised in the background isolate.
// ============================================================================

import 'dart:async';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Foreground service notification channel ID
const String kForegroundChannelId = kServiceStatusChannelId;
const int kForegroundNotificationId = 7777;

/// SharedPreferences keys used to ferry localized strings from the main
/// isolate (where easy_localization is initialised) to the background
/// isolate that owns the foreground service notification.
const String _kPrefForegroundChannelName =
    'foreground_localized_channel_name_v1';
const String _kPrefForegroundChannelDescription =
    'foreground_localized_channel_description_v1';
const String _kPrefForegroundActiveTitle =
    'foreground_localized_active_title_v1';
const String _kPrefForegroundActiveBody = 'foreground_localized_active_body_v1';

/// Brand-only fallback used when easy_localization has not been initialised
/// (e.g., very early app launch before EasyLocalization.ensureInitialized()).
const String _kFallbackBrand = 'KoruBeni';

/// KoruBeni Foreground Service
///
/// Keeps the app alive in the background while an active safety flow is
/// running. The persistent notification stays in the status bar; OS-level
/// constraints may still affect background reliability.
class KoruBeniForegroundService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _isConfigured = false;

  /// Configure the service. Call once at app startup, after
  /// `EasyLocalization.ensureInitialized()` has completed.
  static Future<void> configure() async {
    if (kIsWeb) return;
    if (_isConfigured) return;

    try {
      // Resolve localized strings in the main isolate.
      final channelName = _safeTr(
        'notification_channel_service_name',
        _kFallbackBrand,
      );
      final channelDescription = _safeTr(
        'notification_channel_service_desc',
        _kFallbackBrand,
      );
      final activeTitle = _safeTr('foreground_active_title', _kFallbackBrand);
      final activeBody = _safeTr('foreground_active_body', _kFallbackBrand);

      // Persist for the background isolate.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefForegroundChannelName, channelName);
      await prefs.setString(
        _kPrefForegroundChannelDescription,
        channelDescription,
      );
      await prefs.setString(_kPrefForegroundActiveTitle, activeTitle);
      await prefs.setString(_kPrefForegroundActiveBody, activeBody);

      // Create the notification channel.
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        kForegroundChannelId,
        channelName,
        description: channelDescription,
        importance: Importance.low, // Silent but persistent
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          autoStart: false, // Manual start — only during active safety flow
          isForegroundMode: true,
          notificationChannelId: kForegroundChannelId,
          initialNotificationTitle: activeTitle,
          initialNotificationContent: activeBody,
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

  /// Start the foreground service (call when an active safety flow begins).
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

  /// Stop the foreground service.
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

  /// Is the service running?
  static Future<bool> isRunning() async {
    if (kIsWeb) return false;
    try {
      return await _service.isRunning();
    } catch (_) {
      return false;
    }
  }

  /// Update the persistent notification text.
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

/// Safe wrapper around easy_localization's `.tr()` extension. If the
/// translation lookup throws (e.g. because EasyLocalization has not been
/// initialised yet), fall back to a brand-only string so we never crash
/// during foreground-service configuration.
String _safeTr(String key, String fallback) {
  try {
    final translated = key.tr();
    // easy_localization returns the key itself when no entry is found.
    if (translated == key || translated.isEmpty) return fallback;
    return translated;
  } catch (_) {
    return fallback;
  }
}

// ============================================================================
// BACKGROUND ISOLATE CODE (runs in a separate Dart isolate)
// ============================================================================

/// Top-level entry point — runs in the background isolate.
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Read localized strings written by the main isolate at configure() time.
  final prefs = await SharedPreferences.getInstance();
  final channelName =
      prefs.getString(_kPrefForegroundChannelName) ?? _kFallbackBrand;
  final activeTitle =
      prefs.getString(_kPrefForegroundActiveTitle) ?? _kFallbackBrand;
  final activeBody =
      prefs.getString(_kPrefForegroundActiveBody) ?? _kFallbackBrand;
  var currentTitle = activeTitle;
  var currentBody = activeBody;

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

  // Stop command from the main isolate.
  service.on('stop').listen((_) async {
    heartbeatTimer?.cancel();
    await service.stopSelf();
    debugPrint('ForegroundService: Stopped via command');
  });

  // Notification update command from the main isolate.
  service.on('updateNotification').listen((event) async {
    try {
      if (event != null && service is AndroidServiceInstance) {
        currentTitle = event['title'] as String? ?? currentTitle;
        currentBody = event['content'] as String? ?? currentBody;
        await notificationsPlugin.show(
          kForegroundNotificationId,
          currentTitle,
          currentBody,
          NotificationDetails(
            android: AndroidNotificationDetails(
              kForegroundChannelId,
              channelName,
              icon: 'ic_bg_service_small',
              ongoing: true,
              autoCancel: false,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('ForegroundService: notification update failed: $e');
    }
  });

  // Periodic heartbeat — refresh the notification every 30s so the OS knows
  // we are still alive.
  heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
    try {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          notificationsPlugin.show(
            kForegroundNotificationId,
            currentTitle,
            currentBody,
            NotificationDetails(
              android: AndroidNotificationDetails(
                kForegroundChannelId,
                channelName,
                icon: 'ic_bg_service_small',
                ongoing: true,
                autoCancel: false,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('ForegroundService: heartbeat failed: $e');
    }
  });

  debugPrint('ForegroundService: onStart executed in background isolate');
}

/// iOS background handler.
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
