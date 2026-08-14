import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

import 'notification_service.dart';

/// The notification categories this app actually posts.
///
/// Enumerated rather than derived so a NEW notification cannot appear without a
/// category, which is how "the user has no in-app control over rehearsal nudges"
/// (MP-26-006) happened in the first place: the channels existed, the taxonomy
/// did not.
enum NotificationCategory {
  /// Panic dispatch, check-in expiry, Safe Walk escalation. The reason the app
  /// exists.
  emergencyAlert,

  /// The persistent foreground-service notification while a session is armed.
  /// Android requires it; it cannot be suppressed while the service runs.
  serviceStatus,

  /// The scheduled fake incoming call.
  fakeCall,

  /// Everything else the app may post.
  general;

  /// The Android channel this category posts on.
  String get channelId => switch (this) {
    NotificationCategory.emergencyAlert => kEmergencyAlertsChannelId,
    NotificationCategory.serviceStatus => kServiceStatusChannelId,
    NotificationCategory.fakeCall => kEmergencyAlertsChannelId,
    NotificationCategory.general => kGeneralNotificationsChannelId,
  };

  String get titleKey => switch (this) {
    NotificationCategory.emergencyAlert => 'notification_category_emergency',
    NotificationCategory.serviceStatus => 'notification_category_service',
    NotificationCategory.fakeCall => 'notification_category_fake_call',
    NotificationCategory.general => 'notification_category_general',
  };

  String get descriptionKey => switch (this) {
    NotificationCategory.emergencyAlert =>
      'notification_category_emergency_desc',
    NotificationCategory.serviceStatus => 'notification_category_service_desc',
    NotificationCategory.fakeCall => 'notification_category_fake_call_desc',
    NotificationCategory.general => 'notification_category_general_desc',
  };

  /// Categories whose delivery the product must not encourage switching off.
  ///
  /// The app does NOT enforce this — Android owns the switch, and pretending
  /// otherwise would be the second disagreeing copy this design already
  /// rejected. It changes what the screen SAYS: muting the emergency channel is
  /// shown as a warning, not as a neutral preference.
  bool get isSafetyCritical => switch (this) {
    NotificationCategory.emergencyAlert => true,
    NotificationCategory.serviceStatus => true,
    _ => false,
  };
}

/// What Android currently reports about one category.
///
/// Every field is READ from the platform. The app deliberately holds no
/// second copy of the answer: a local switch that said ON while the OS said
/// OFF is exactly how the app came to promise alerts it could not deliver.
class NotificationCategoryState {
  const NotificationCategoryState({
    required this.category,
    required this.appLevelEnabled,
    required this.channelExists,
    required this.channelImportance,
  });

  final NotificationCategory category;

  /// Whether Android will show ANY notification from this app.
  final bool appLevelEnabled;

  /// Whether the channel has been created yet (it is created on first init).
  final bool channelExists;

  /// The channel's current importance, or null when unknown.
  final Importance? channelImportance;

  /// The user has muted this channel in Android settings.
  bool get channelMuted =>
      channelExists && channelImportance == Importance.none;

  /// Android will actually surface a notification of this category.
  bool get willBeDelivered => appLevelEnabled && !channelMuted;

  /// A safety-critical category the user has switched off. The screen says so
  /// plainly instead of showing a tidy grey toggle.
  bool get isSilencedSafetySurface => category.isSafetyCritical && !willBeDelivered;

  Map<String, Object?> toMap() => <String, Object?>{
    'category': category.name,
    'channelId': category.channelId,
    'appLevelEnabled': appLevelEnabled,
    'channelExists': channelExists,
    'channelImportance': channelImportance?.value,
    'willBeDelivered': willBeDelivered,
    'safetyCritical': category.isSafetyCritical,
  };
}

/// Reads the LIVE per-category notification state, and opens the right Android
/// screen to change it.
///
/// MP-23-010 / MP-26-006 asked for either in-app per-category toggles or an
/// explicit statement that channel control lives in Android settings, with a
/// link. This does the stronger version of the second: per CATEGORY, with the
/// platform's current answer shown next to it, and a link that lands on that
/// category's own channel screen rather than the app's notification root.
class NotificationPreferencesService {
  NotificationPreferencesService({
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel? settingsChannel,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _settingsChannel =
           settingsChannel ??
           const MethodChannel('com.poyrazoncel.korubeni/settings');

  static final NotificationPreferencesService instance =
      NotificationPreferencesService();

  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _settingsChannel;

  /// One entry per category, in declaration order.
  Future<List<NotificationCategoryState>> readAll() async {
    await NotificationService.instance.initialize();
    final appLevel =
        await NotificationService.instance.areSystemNotificationsEnabled();
    final channels = await _channels();
    return NotificationCategory.values
        .map(
          (category) => NotificationCategoryState(
            category: category,
            appLevelEnabled: appLevel,
            channelExists: channels.containsKey(category.channelId),
            channelImportance: channels[category.channelId],
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, Importance>> _channels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return const <String, Importance>{};
    try {
      final channels = await android.getNotificationChannels();
      return <String, Importance>{
        for (final channel in channels ?? const <AndroidNotificationChannel>[])
          channel.id: channel.importance,
      };
    } on PlatformException {
      return const <String, Importance>{};
    } on MissingPluginException {
      return const <String, Importance>{};
    }
  }

  /// Opens Android's settings screen for this category's channel.
  Future<bool> openSettingsFor(NotificationCategory category) async {
    try {
      final ok = await _settingsChannel.invokeMethod<bool>(
        'openNotificationChannelSettings',
        <String, Object?>{'channelId': category.channelId},
      );
      return ok == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
