import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app_settings_service.dart';
import '../navigation/app_navigator.dart';
import '../utils/permission_helper.dart';
import '../../screens/fake_call_screen.dart';

const String kEmergencyAlertsChannelId = 'emergency_alerts';
const String kEmergencyAlertsChannelName = 'Acil Bildirimler';
const String kServiceStatusChannelId = 'service_status';
const String kServiceStatusChannelName = 'Servis Durumu';
const String kGeneralNotificationsChannelId = 'general_notifications';
const String kGeneralNotificationsChannelName = 'Genel Bildirimler';
const String kNotificationGroupKey = 'korubeni_alerts';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _timezoneInitialized = false;
  int _activeNotificationCount = 0;

  Future<void> initialize() async {
    if (_initialized) return;

    _initializeTimezone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        kEmergencyAlertsChannelId,
        kEmergencyAlertsChannelName,
        description: 'Kritik güvenlik ve check-in bildirimleri',
        importance: Importance.max,
      ),
    );
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        kServiceStatusChannelId,
        kServiceStatusChannelName,
        description: 'Arka plan güvenlik servis durumu',
        importance: Importance.low,
      ),
    );
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        kGeneralNotificationsChannelId,
        kGeneralNotificationsChannelName,
        description: 'Genel uygulama bildirimleri',
        importance: Importance.defaultImportance,
      ),
    );
    _initialized = true;
  }

  void _initializeTimezone() {
    if (_timezoneInitialized) return;
    tz_data.initializeTimeZones();
    _timezoneInitialized = true;
  }

  Future<void> showEmergencyAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!await AppSettingsService.notificationsEnabled()) {
      return;
    }

    await initialize();
    _activeNotificationCount++;

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kEmergencyAlertsChannelId,
          kEmergencyAlertsChannelName,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          groupKey: kNotificationGroupKey,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    // Show group summary if multiple notifications
    if (_activeNotificationCount > 1) {
      await _showGroupSummary();
    }
  }

  Future<NotificationPermissionRequestStatus>
  ensureNotificationPermissionForScheduledAction(BuildContext context) async {
    return PermissionHelper.requestNotificationPermissionForScheduledAction(
      context,
    );
  }

  Future<bool> scheduleFakeCall({required Duration delay}) async {
    if (!await AppSettingsService.notificationsEnabled()) {
      return false;
    }
    try {
      await initialize();
      final scheduledAt = tz.TZDateTime.now(tz.local).add(delay);
      await _plugin.zonedSchedule(
        31001,
        'Sahte çağrı hazır',
        'Sahte çağrı ekranını açmak için dokunun.',
        scheduledAt,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            kEmergencyAlertsChannelId,
            kEmergencyAlertsChannelName,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'fake_call',
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload != 'fake_call') return;
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(MaterialPageRoute(builder: (_) => const FakeCallScreen()));
  }

  /// Shows a summary notification that groups individual alerts.
  Future<void> _showGroupSummary() async {
    await _plugin.show(
      0, // Use 0 for summary
      'KoruBeni',
      '$_activeNotificationCount bildirim',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kEmergencyAlertsChannelId,
          kEmergencyAlertsChannelName,
          importance: Importance.max,
          priority: Priority.max,
          groupKey: kNotificationGroupKey,
          setAsGroupSummary: true,
        ),
      ),
    );
  }

  /// Reset notification count (call when user opens app).
  void resetNotificationCount() {
    _activeNotificationCount = 0;
  }
}
