import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app_settings_service.dart';
import 'emergency_platform_service.dart';
import '../navigation/app_navigator.dart';
import '../utils/permission_helper.dart';
import '../../screens/fake_call_screen.dart';

const String kEmergencyAlertsChannelId = 'emergency_alerts';
const String kServiceStatusChannelId = 'service_status';
const String kGeneralNotificationsChannelId = 'general_notifications';
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
      AndroidNotificationChannel(
        kEmergencyAlertsChannelId,
        'notification_channel_emergency_name'.tr(),
        description: 'notification_channel_emergency_desc'.tr(),
        importance: Importance.max,
      ),
    );
    await androidImplementation?.createNotificationChannel(
      AndroidNotificationChannel(
        kServiceStatusChannelId,
        'notification_channel_service_name'.tr(),
        description: 'notification_channel_service_desc'.tr(),
        importance: Importance.low,
      ),
    );
    await androidImplementation?.createNotificationChannel(
      AndroidNotificationChannel(
        kGeneralNotificationsChannelId,
        'notification_channel_general_name'.tr(),
        description: 'notification_channel_general_desc'.tr(),
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
      NotificationDetails(
        android: AndroidNotificationDetails(
          kEmergencyAlertsChannelId,
          'notification_channel_emergency_name'.tr(),
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          groupKey: kNotificationGroupKey,
        ),
        iOS: const DarwinNotificationDetails(
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
      final canExact =
          await EmergencyPlatformService.instance.canScheduleExactAlarms();
      if (!canExact) return false;
      await _plugin.zonedSchedule(
        31001,
        'fake_call_notification_title'.tr(),
        'fake_call_notification_body'.tr(),
        scheduledAt,
        NotificationDetails(
          android: AndroidNotificationDetails(
            kEmergencyAlertsChannelId,
            'notification_channel_emergency_name'.tr(),
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            visibility: NotificationVisibility.public,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'fake_call',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // uiLocalNotificationDateInterpretation parameter was removed in
        // flutter_local_notifications v19 (legacy iOS notifications API).
        // Behavior is now always absoluteTime on supported iOS versions.
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
      'notification_group_summary'.tr(
        namedArgs: {'count': '$_activeNotificationCount'},
      ),
      NotificationDetails(
        android: AndroidNotificationDetails(
          kEmergencyAlertsChannelId,
          'notification_channel_emergency_name'.tr(),
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
