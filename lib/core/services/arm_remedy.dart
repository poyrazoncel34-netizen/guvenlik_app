import 'emergency_platform_service.dart';

/// What fixes a refused panic, offered on the blocked-arm dialog in one tap
/// (2026-11-02).
///
/// The refusal rule itself is deliberate and stays: native refuses a panic it
/// cannot protect (`CapabilitySnapshot.rejectionReason()`), and Dart refuses
/// one it may not start (entitlement, PIN, target). What was wrong is that
/// almost every refusal ended on a dialog whose only button was "Kapat". On an
/// Android 14+ clean install exact-alarm access is OFF by default, so the
/// first real panic of a new Pro user was the likeliest place to meet it.
///
/// Each value names the ONE screen that removes its refusal. A refusal with no
/// value here is one nothing on this device can fix (no telephony, a protocol
/// mismatch); the dialog then still offers the manual call
/// (`PanicArmPolicy.manualDialNumber`).
enum ArmRemedy {
  /// Android's "Alarms & reminders" toggle, through `ExactAlarmSettingsIntent`.
  exactAlarm('background_protection_open'),

  /// The CALL_PHONE runtime request, with its prominent disclosure.
  callPermission('panic_fix_call_permission'),

  /// The app's notification settings (ACTION_APP_NOTIFICATION_SETTINGS).
  notifications('open_notification_settings'),

  /// The emergency alert channel's own settings
  /// (ACTION_CHANNEL_NOTIFICATION_SETTINGS).
  alertChannel('panic_fix_alert_channel'),

  /// The emergency contact list.
  emergencyContact('select_emergency_contact'),

  /// PIN creation. Opened only when no PIN exists: a stored PIN is changed
  /// through the old-PIN check, never replaced from here.
  pinSetup('pin_setup_button'),

  /// The PIN sheet, for a PIN that exists but could not be read.
  pinSettings('settings_pin_title'),

  /// The paywall, which also restores purchases.
  subscription('panic_fix_subscription');

  const ArmRemedy(this.labelKey);

  /// Translation key of the button that applies this remedy.
  final String labelKey;

  /// The device capabilities, in the order `rejectionReason()` checks them.
  ///
  /// Fixing one can expose the next, so a surface offering one of these reads
  /// readiness again when the user is back from Settings instead of trusting
  /// the refusal code it was opened with.
  static const List<ArmRemedy> capabilityOrder = <ArmRemedy>[
    exactAlarm,
    callPermission,
    notifications,
    alertChannel,
  ];

  bool get isCapability => capabilityOrder.contains(this);

  /// The capabilities [readiness] lacks, in native refusal order.
  ///
  /// Empty for an unknown snapshot: a probe that failed is not evidence that
  /// anything is missing, and asking for a permission the user already granted
  /// would teach them to ignore the prompt.
  static List<ArmRemedy> missingCapabilities(
    PlatformReadinessSnapshot readiness,
  ) {
    if (!readiness.isKnown) return const <ArmRemedy>[];
    return <ArmRemedy>[
      if (!readiness.exactAlarmPermission) exactAlarm,
      if (!readiness.callPermission) callPermission,
      if (!readiness.notificationPermission) notifications,
      if (!readiness.alertChannelHigh) alertChannel,
    ];
  }
}

/// A blocked arm as the failure dialog needs it: the sentence explaining it
/// and what fixes it, handed over together so the two cannot be paired from
/// different refusals.
class ArmRefusal {
  const ArmRefusal({required this.bodyKey, this.remedy});

  final String bodyKey;

  /// Null when nothing on this device fixes the refusal.
  final ArmRemedy? remedy;
}
