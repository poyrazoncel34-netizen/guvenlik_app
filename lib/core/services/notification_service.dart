import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String kEmergencyAlertsChannelId = 'emergency_alerts';
const String kEmergencyAlertsChannelName = 'Acil Bildirimler';
const String kNotificationGroupKey = 'korubeni_alerts';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _activeNotificationCount = 0;

  Future<void> initialize() async {
    if (_initialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            kEmergencyAlertsChannelId,
            kEmergencyAlertsChannelName,
            description: 'Kritik güvenlik ve check-in bildirimleri',
            importance: Importance.max,
          ),
        );
    _initialized = true;
  }

  Future<void> showEmergencyAlert({
    required int id,
    required String title,
    required String body,
  }) async {
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
