import 'package:flutter/material.dart';

import '../../screens/contacts_page.dart';
import '../../screens/pin_setup_screen.dart';
import '../services/arm_remedy.dart';
import '../services/emergency_platform_service.dart';
import '../services/emergency_session_contract.dart';
import '../services/notification_preferences_service.dart';
import '../services/pin_verification_service.dart';
import '../services/subscription_gate.dart';
import '../utils/permission_helper.dart';
import '../utils/pin_settings_helper.dart';

typedef RemedyScreenOpener = Future<void> Function(BuildContext context);

/// Opens the one screen that removes a refused panic (2026-11-02).
///
/// Every opener is a field so a test can see WHICH screen a remedy reaches.
/// The defaults are the production paths, and a test pins them by identity:
/// a launcher that called "something" would prove nothing.
class ArmRemedyLauncher {
  const ArmRemedyLauncher({
    this.platform,
    this.notificationPreferences,
    this.requestCallPermission = PermissionHelper.requestCallPhonePermission,
    this.openNotificationSettings = PermissionHelper.openNotificationSettings,
    this.openContacts = ArmRemedyScreens.contacts,
    this.openPin = ArmRemedyScreens.pin,
    this.openSubscription = ArmRemedyScreens.subscription,
  });

  final EmergencyPlatformService? platform;
  final NotificationPreferencesService? notificationPreferences;
  final Future<bool> Function(BuildContext context) requestCallPermission;
  final Future<bool> Function() openNotificationSettings;
  final RemedyScreenOpener openContacts;
  final RemedyScreenOpener openPin;
  final RemedyScreenOpener openSubscription;

  Future<void> apply(BuildContext context, ArmRemedy remedy) async {
    switch (remedy) {
      case ArmRemedy.exactAlarm:
        // ExactAlarmSettingsIntent: this package's own toggle, falling back to
        // the app details page, never the generic list.
        await (platform ?? EmergencyPlatformService.instance)
            .requestExactAlarmPermission();
      case ArmRemedy.callPermission:
        await requestCallPermission(context);
      case ArmRemedy.notifications:
        await openNotificationSettings();
      case ArmRemedy.alertChannel:
        await (notificationPreferences ??
                NotificationPreferencesService.instance)
            .openSettingsFor(NotificationCategory.emergencyAlert);
      case ArmRemedy.emergencyContact:
        await openContacts(context);
      case ArmRemedy.pinSetup || ArmRemedy.pinSettings:
        await openPin(context);
      case ArmRemedy.subscription:
        await openSubscription(context);
    }
  }
}

/// The in-app screens a remedy opens.
abstract final class ArmRemedyScreens {
  static Future<void> contacts(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ContactsPage()));

  /// PIN creation only while no PIN exists. A stored PIN, including one that
  /// could not be read just now, goes to the change sheet, which asks for the
  /// old PIN first: replacing it from an emergency surface without that check
  /// would hand whoever holds the phone the cancel code.
  static Future<void> pin(
    BuildContext context, {
    PinVerificationService? pins,
  }) async {
    final state = await (pins ?? PinVerificationService.instance).loadState();
    if (!context.mounted) return;
    if (state == PinState.absent) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const PinSetupScreen(),
        ),
      );
      return;
    }
    PinSettingsHelper.showPinChangeSheet(context);
  }

  static Future<void> subscription(BuildContext context) =>
      SubscriptionGate.showPaywall(
        context,
        lockedFeature: PremiumFeature.panic,
      );
}
