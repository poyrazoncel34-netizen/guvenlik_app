// Y-11 (owner decision 2026-10-09): the home readiness chip "Arka Plan
// Hazırlığı" is red whenever exact-alarm access, notifications or the alert
// channel is missing -- but it always opened the battery wizard, which fixes
// none of them. On an API 36 clean install the red chip was the only visible
// hint and it led nowhere near the exact-alarm setting.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/widgets/background_protection_fix.dart';
import 'package:guvenlik_app/screens/battery_optimization_wizard.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlatformReadinessSnapshot _readiness({
  bool exactAlarm = true,
  bool notifications = true,
  bool alertChannel = true,
}) => PlatformReadinessSnapshot(
  supportedOs: true,
  telephonyCalling: true,
  telecomAvailable: true,
  dialHandlerAvailable: true,
  batteryOptimizationWhitelisted: false,
  exactAlarmPermission: exactAlarm,
  callPermission: true,
  notificationPermission: notifications,
  alertChannelHigh: alertChannel,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  late List<String> nativeCalls;
  late int notificationSettingsOpened;

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    nativeCalls = <String>[];
    notificationSettingsOpened = 0;
    const channel = MethodChannel('background-protection-fix');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      nativeCalls.add(call.method);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return captured;
  }

  Future<void> open(
    WidgetTester tester,
    BuildContext context,
    PlatformReadinessSnapshot? readiness,
  ) async {
    // Not awaited: the battery branch completes only when its route pops.
    unawaited(
      BackgroundProtectionFix.open(
        context,
        readiness: readiness,
        platform: EmergencyPlatformService.forTesting(
          methodChannel: const MethodChannel('background-protection-fix'),
        ),
        openNotificationSettings: () async {
          notificationSettingsOpened++;
          return true;
        },
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('missing exact-alarm access opens the exact-alarm settings', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    await open(tester, context, _readiness(exactAlarm: false));

    expect(nativeCalls, <String>['requestExactAlarmPermission']);
    expect(notificationSettingsOpened, 0);
    expect(find.byType(BatteryOptimizationWizard), findsNothing);
  });

  testWidgets('missing notifications or alert channel opens notification '
      'settings', (tester) async {
    final context = await pumpHost(tester);
    await open(tester, context, _readiness(notifications: false));
    await open(tester, context, _readiness(alertChannel: false));

    expect(notificationSettingsOpened, 2);
    expect(nativeCalls, isEmpty);
  });

  testWidgets('with every alert prerequisite in place it is the battery '
      'wizard, as before', (tester) async {
    final context = await pumpHost(tester);
    await open(tester, context, _readiness());

    expect(find.byType(BatteryOptimizationWizard), findsOneWidget);
    expect(nativeCalls, isEmpty);
  });
}
