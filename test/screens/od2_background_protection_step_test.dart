// OD-2 (owner decision 2026-10-11): on a clean Android 14+ install the
// "Alarms & reminders" special access is off, so a protected Panic cannot be
// armed -- and before this step the user discovered that by pressing the panic
// button. Onboarding now carries a VISIBLE "Arka Plan Koruması" step that
// explains it and opens the setting on a tap, without throwing the user into
// Settings unasked and without blocking completion.
//
// These are behaviour tests against the real widget: what the step shows, what
// it opens, and that it re-reads the permission on resume rather than trusting
// an Activity result.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_readiness_service.dart';
import 'package:guvenlik_app/core/services/safety_readiness_level.dart';
import 'package:guvenlik_app/core/widgets/readiness_card.dart';
import 'package:guvenlik_app/core/widgets/minimum_tap_target.dart';
import 'package:guvenlik_app/screens/onboarding/onboarding_background_protection_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

/// Every boolean the native readiness probe returns, so a test can flip one.
Map<String, Object?> _readinessMap({
  bool exactAlarm = true,
  bool supportedOs = true,
  bool notifications = true,
}) => <String, Object?>{
  'supportedOs': supportedOs,
  'telephonyCalling': true,
  'telecomAvailable': true,
  'dialHandlerAvailable': true,
  'batteryOptimizationsIgnored': true,
  'canScheduleExactAlarms': exactAlarm,
  'callPermissionGranted': true,
  'notificationsEnabled': notifications,
  'alertChannelHigh': notifications,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(EmergencyPlatformService.channelName);

  /// Calls the step saw, so "it opened Settings" is proven, not assumed.
  late List<String> calls;
  late bool exactAlarmGranted;
  /// Notifications are requested AFTER this step in the real flow, so the
  /// step must behave correctly while they are still denied.
  late bool notificationsGranted;

  EmergencyReadinessService buildReadiness() {
    calls = <String>[];
    notificationsGranted = true;
    final platform = EmergencyPlatformService.forTesting(
      methodChannel: channel,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'getDeviceState':
              return _readinessMap(
                exactAlarm: exactAlarmGranted,
                notifications: notificationsGranted,
              );
            case 'canScheduleExactAlarms':
              return exactAlarmGranted;
            case 'requestExactAlarmPermission':
              return null;
          }
          return null;
        });
    return EmergencyReadinessService.forTesting(platformService: platform);
  }

  setUpAll(() async {
    // EasyLocalization reads SharedPreferences for the saved locale.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<EmergencyReadinessService> pumpStep(WidgetTester tester) async {
    final readiness = buildReadiness();
    await pumpLocalized(
      tester,
      OnboardingBackgroundProtectionStep(readiness: readiness),
    );
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 300),
        ));
    await tester.pump();
    return readiness;
  }

  testWidgets(
    'with the permission missing the step says so and offers the CTA',
    (tester) async {
      exactAlarmGranted = false;
      await pumpStep(tester);

      expect(find.text('Arka Plan Koruması'), findsOneWidget);
      expect(find.text('Alarm ve hatırlatıcı erişimi kapalı.'), findsOneWidget);
      expect(find.text('Arka plan korumasını aç'), findsOneWidget);
      // The user must be told skipping is allowed AND what it costs.
      expect(
        find.textContaining('kurulum eksik kalır'),
        findsOneWidget,
      );
      // It must NOT have opened Settings on its own (OD-2's first rule).
      expect(calls, isNot(contains('requestExactAlarmPermission')));
    },
  );

  testWidgets('with the permission granted no CTA is shown', (tester) async {
    exactAlarmGranted = true;
    await pumpStep(tester);

    expect(find.text('Alarm ve hatırlatıcı erişimi açık.'), findsOneWidget);
    expect(find.text('Arka plan korumasını aç'), findsNothing);
    expect(calls, isNot(contains('requestExactAlarmPermission')));
  });

  testWidgets('the CTA opens the exact-alarm setting', (tester) async {
    exactAlarmGranted = false;
    await pumpStep(tester);

    await tester.tap(find.text('Arka plan korumasını aç'));
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 200),
        ));
    await tester.pump();

    expect(calls, contains('requestExactAlarmPermission'));
  });

  testWidgets(
    'returning from Settings re-reads the permission instead of trusting a result',
    (tester) async {
      exactAlarmGranted = false;
      await pumpStep(tester);
      expect(find.text('Alarm ve hatırlatıcı erişimi kapalı.'), findsOneWidget);

      // The user grants it in Android Settings and comes back. Nothing tells
      // the app the toggle changed -- the resume is the only signal.
      exactAlarmGranted = true;
      final probesBefore = calls.where((c) => c == 'getDeviceState').length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 300),
          ));
      await tester.pump();

      expect(
        calls.where((c) => c == 'getDeviceState').length,
        greaterThan(probesBefore),
        reason: 'resume must re-probe; an Activity result is not authoritative',
      );
      expect(find.text('Alarm ve hatırlatıcı erişimi açık.'), findsOneWidget);
      expect(find.text('Arka plan korumasını aç'), findsNothing);
    },
  );

  testWidgets('a readiness probe that fails is not reported as ready', (
    tester,
  ) async {
    calls = <String>[];
    final platform = EmergencyPlatformService.forTesting(
      methodChannel: channel,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          throw PlatformException(code: 'unavailable');
        });
    final readiness = EmergencyReadinessService.forTesting(
      platformService: platform,
    );
    await pumpLocalized(
      tester,
      OnboardingBackgroundProtectionStep(readiness: readiness),
    );
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 300),
        ));
    await tester.pump();

    expect(find.text('Alarm ve hatırlatıcı erişiminin durumu okunamadı.'), findsOneWidget);
    expect(find.text('Alarm ve hatırlatıcı erişimi açık.'), findsNothing);
  });

  testWidgets('the CTA is at least 48 dp in GLOBAL coordinates', (
    tester,
  ) async {
    exactAlarmGranted = false;
    await pumpStep(tester);

    // Measured with tester.getRect in GLOBAL coordinates, never
    // SemanticsNode.rect (MP-80). MinimumTapTarget is the wrapper that
    // GUARANTEES the floor; an OutlinedButton's own internal GestureDetector
    // reports the painted 40 dp, which is why the box under test is named
    // explicitly rather than taken as "the first GestureDetector".
    final label = tester.getRect(find.text('Arka plan korumasını aç'));
    final tappable = tester.getRect(
      find.ancestor(
        of: find.text('Arka plan korumasını aç'),
        matching: find.byType(MinimumTapTarget),
      ),
    );
    expect(
      tappable.height,
      greaterThanOrEqualTo(48.0),
      reason: 'interactive box ${tappable.height} dp, label ${label.height} dp',
    );
    expect(tappable.width, greaterThanOrEqualTo(48.0));
  });

  testWidgets('TalkBack reads the whole step, explanation included', (
    tester,
  ) async {
    // The step's job is to EXPLAIN a permission. A screen-reader user who
    // hears only "Arka Plan Koruması / kapalı / aç" has been told to change a
    // setting without being told why, so the body and the skip note are part
    // of the accessibility contract, not decoration.
    //
    // Asserted against Flutter's own semantics tree rather than an
    // `adb shell uiautomator dump`: that dump omits these two nodes on API 36
    // while the tree contains them, so the dump would have reported a defect
    // that does not exist. (Verified both ways on 2026-10-11.)
    exactAlarmGranted = false;
    final handle = tester.ensureSemantics();
    await pumpStep(tester);

    // find.bySemanticsLabel searches the live semantics tree, which is exactly
    // what a screen reader walks.
    for (final fragment in <String>[
      'Arka Plan Koruması',
      'Alarm ve hatırlatıcı erişimi kapalı.',
      'Arka plan korumasını aç',
      // The explanation of WHY the access is needed...
      'alarm ve hatırlatıcı',
      // ...and the cost of skipping it.
      'kurulum eksik kalır',
    ]) {
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(fragment))),
        findsWidgets,
        reason: 'a screen reader must be able to reach "$fragment"',
      );
    }
    handle.dispose();
  });

  testWidgets('the status line names the ONE access this step controls', (
    tester,
  ) async {
    // Review MEDIUM: `granted` is exactAlarmPermission, while the home chip is
    // backgroundAlertReady (also notifications + a high-importance channel),
    // and notifications are requested LATER in this flow. So the step must not
    // say "background protection is on" off the narrower signal -- its CTA
    // cannot grant notifications, so widening the signal would show red for
    // something it cannot fix. It names the alarm access instead.
    exactAlarmGranted = true;
    await pumpStep(tester);

    expect(find.text('Alarm ve hatırlatıcı erişimi açık.'), findsOneWidget);
    expect(find.textContaining('Arka plan koruması açık'), findsNothing);
  });

  testWidgets(
    'with notifications still denied the step reports only the alarm access',
    (tester) async {
      // The scenario the narrow signal exists for, and the one that makes
      // widening it wrong. In this flow the notification permission is
      // requested AFTER this step, so `backgroundAlertReady` is false here for
      // a reason this step cannot address: its CTA opens the exact-alarm
      // screen. Reporting "off" would send the user to a setting that is
      // already correct; the step reports the access it actually owns.
      exactAlarmGranted = true;
      final readiness = buildReadiness();
      notificationsGranted = false;
      await pumpLocalized(
        tester,
        OnboardingBackgroundProtectionStep(readiness: readiness),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();

      expect(find.text('Alarm ve hatırlatıcı erişimi açık.'), findsOneWidget);
      expect(find.text('Alarm ve hatırlatıcı erişimi kapalı.'), findsNothing);
      expect(find.text('Arka plan korumasını aç'), findsNothing);
      // ...and the overall verdict is still NOT ready, which the card owns.
      expect(
        readiness.lastState.readinessLevel,
        SafetyReadinessLevel.limited,
      );
    },
  );

  testWidgets('a readiness change from elsewhere repaints the step', (
    tester,
  ) async {
    // Review MEDIUM: the step used to await only its own probe. The service
    // supersedes an in-flight probe and does NOT notify for the superseded
    // one, so without a listener the step could paint stale state and never
    // hear the newer result. Here the service is driven directly, with no
    // lifecycle event and no probe of the step's own.
    exactAlarmGranted = false;
    final readiness = await pumpStep(tester);
    expect(find.text('Alarm ve hatırlatıcı erişimi kapalı.'), findsOneWidget);

    exactAlarmGranted = true;
    await tester.runAsync(() => readiness.checkReadiness());
    await tester.pump();

    expect(find.text('Alarm ve hatırlatıcı erişimi açık.'), findsOneWidget);
  });

  group('the home card speaks the same verdict', () {
    Widget card(PlatformReadinessSnapshot? readiness) => ReadinessCard(
      locationGranted: true,
      contactsGranted: true,
      hasEmergencyContact: true,
      readiness: readiness,
      lastRehearsalAt: null,
      onFixEmergencyContact: () {},
      onFixCallPermission: () {},
      onFixBackground: () {},
      onFixLocation: () {},
      onFixContacts: () {},
      onRunRehearsal: () {},
    );

    testWidgets('a readiness probe that failed is named, not counted', (
      tester,
    ) async {
      // "Kuruluma 2 adım kaldı" sends the user hunting through Settings for
      // steps that are not the problem: the probe itself did not answer. This
      // state needs its own words, which is why SafetyReadinessLevel has three
      // values and not a boolean.
      await pumpLocalized(
        tester,
        card(const PlatformReadinessSnapshot.unavailable(reasonCode: 'timeout')),
      );

      expect(find.text('Hazırlık durumu okunamadı'), findsOneWidget);
      expect(find.textContaining('Kuruluma'), findsNothing);
      expect(find.text('Kurulum tamam'), findsNothing);
    });

    testWidgets('a missing exact alarm is counted as a step, not an error', (
      tester,
    ) async {
      await pumpLocalized(
        tester,
        card(PlatformReadinessSnapshot.fromMap(
          _readinessMap(exactAlarm: false).cast<String, dynamic>(),
        )),
      );

      expect(find.text('Hazırlık durumu okunamadı'), findsNothing);
      expect(find.text('Kurulum tamam'), findsNothing);
      // One chip red -> the "almost there" headline, with a next action.
      expect(find.textContaining('Kurulumun büyük bölümü tamam'), findsOneWidget);
    });

    testWidgets('a not-yet-probed card does not flash an error headline', (
      tester,
    ) async {
      // Review MEDIUM: null (not probed yet) also maps to `unavailable`, so
      // the card briefly claimed the readiness state could not be read before
      // the very first probe returned.
      await pumpLocalized(tester, card(null));

      expect(find.text('Hazırlık durumu okunamadı'), findsNothing);
    });

    testWidgets('a failed probe never hides "add your contact first"', (
      tester,
    ) async {
      // Review MEDIUM + audit A-04: with no contact saved that is the only
      // instruction that matters, and a failed device probe must not outrank
      // it.
      await pumpLocalized(
        tester,
        ReadinessCard(
          locationGranted: true,
          contactsGranted: true,
          hasEmergencyContact: false,
          readiness: const PlatformReadinessSnapshot.unavailable(
            reasonCode: 'timeout',
          ),
          lastRehearsalAt: null,
          onFixEmergencyContact: () {},
          onFixCallPermission: () {},
          onFixBackground: () {},
          onFixLocation: () {},
          onFixContacts: () {},
          onRunRehearsal: () {},
        ),
      );

      expect(find.text('Hazırlık durumu okunamadı'), findsNothing);
      expect(find.textContaining('acil kişini'), findsOneWidget);
    });

    testWidgets('everything present is the only state that says ready', (
      tester,
    ) async {
      await pumpLocalized(
        tester,
        card(PlatformReadinessSnapshot.fromMap(
          _readinessMap().cast<String, dynamic>(),
        )),
      );

      expect(find.text('Kurulum tamam'), findsOneWidget);
    });
  });

  group('SafetyReadinessLevel is the single source for readiness copy', () {
    test('a null snapshot is never ready', () {
      const PlatformReadinessSnapshot? absent = null;
      expect(absent.readinessLevel, SafetyReadinessLevel.unavailable);
    });

    test('an unavailable snapshot is unavailable, not limited', () {
      const snapshot = PlatformReadinessSnapshot.unavailable(
        reasonCode: 'timeout',
      );
      expect(snapshot.readinessLevel, SafetyReadinessLevel.unavailable);
    });

    test('a missing exact alarm is limited, never fullyReady', () {
      final snapshot = PlatformReadinessSnapshot.fromMap(
        _readinessMap(exactAlarm: false).cast<String, dynamic>(),
      );
      expect(snapshot, isNotNull);
      expect(snapshot.readinessLevel, SafetyReadinessLevel.limited);
      expect(snapshot!.criticalSafetyReady, isFalse);
    });

    test('everything present is fullyReady', () {
      final snapshot = PlatformReadinessSnapshot.fromMap(
        _readinessMap().cast<String, dynamic>(),
      );
      expect(snapshot.readinessLevel, SafetyReadinessLevel.fullyReady);
    });

    test('an unsupported OS is unavailable, not limited', () {
      final snapshot = PlatformReadinessSnapshot.fromMap(
        _readinessMap(supportedOs: false).cast<String, dynamic>(),
      );
      expect(snapshot.readinessLevel, SafetyReadinessLevel.unavailable);
    });
  });
}
