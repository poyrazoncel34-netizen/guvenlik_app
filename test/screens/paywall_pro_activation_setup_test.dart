// Pro activation walks the user through what a protected panic needs
// (2026-11-02).
//
// Before this, buying or restoring Pro closed the paywall with a SnackBar and
// nothing else. On an Android 14+ clean install exact-alarm access is OFF by
// default, so the new Pro user's FIRST real panic was refused. The paywall now
// asks, one at a time and in the order native refuses them, for each missing
// capability before it closes.
//
// Real PaywallScreen, real Turkish catalogue; the store and the platform are
// stubbed at their boundaries.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/panic_countdown_guard.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:guvenlik_app/screens/subscription/paywall_screen.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> trCatalogue() =>
    jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
        as Map<String, dynamic>;

String tr(String key) => (trCatalogue()[key] as String?) ?? '<missing:$key>';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      trCatalogue();
}

/// A store that says yes: purchase and restore both make the account Pro.
class _ActivatingProvider extends SubscriptionProvider {
  bool _pro = false;
  int purchases = 0;
  int restores = 0;

  static const _context = PresentedOfferingContext('default', null, null);

  static Package _package(String id, PackageType type, String price) => Package(
    id,
    type,
    StoreProduct(id, 'KoruBeni Pro', 'KoruBeni Pro', 0.0, price, 'TRY'),
    _context,
  );

  @override
  bool get isPro => _pro;
  @override
  bool get isLoading => false;
  @override
  Offerings? get offerings => null;
  @override
  bool get hasRequiredPackages => true;
  @override
  Package? get monthlyPackage =>
      _package('\$rc_monthly', PackageType.monthly, '₺49,99');
  @override
  Package? get annualPackage =>
      _package('\$rc_annual', PackageType.annual, '₺399,99');
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> purchasePackage(Package package) async {
    purchases++;
    _pro = true;
    return null;
  }

  @override
  Future<String?> restorePurchases() async {
    restores++;
    _pro = true;
    return null;
  }
}

Map<String, Object?> readinessMap({Set<String> missing = const <String>{}}) =>
    <String, Object?>{
      for (final key in const <String>[
        'supportedOs',
        'telephonyCalling',
        'telecomAvailable',
        'dialHandlerAvailable',
        'batteryOptimizationsIgnored',
        'canScheduleExactAlarms',
        'callPermissionGranted',
        'notificationsEnabled',
        'alertChannelHigh',
      ])
        key: !missing.contains(key),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const platformChannel = MethodChannel(EmergencyPlatformService.channelName);
  late Map<String, Object?> deviceState;
  late List<String> platformCalls;
  late _ActivatingProvider store;
  final navigatorKey = GlobalKey<NavigatorState>();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    deviceState = readinessMap();
    platformCalls = <String>[];
    PanicCountdownGuard.resetForTesting();
  });

  tearDown(PanicCountdownGuard.resetForTesting);

  Future<void> pumpOpenPaywall(WidgetTester tester) async {
    // Tall surface: the restore action sits below the fold otherwise.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1080, 3600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(platformChannel, (call) async {
      platformCalls.add(call.method);
      return switch (call.method) {
        'getDeviceState' => deviceState,
        'canScheduleExactAlarms' => deviceState['canScheduleExactAlarms'],
        _ => null,
      };
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(platformChannel, null),
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr', 'TR')],
        path: 'assets/translations',
        assetLoader: const _RealTrAssetLoader(),
        startLocale: const Locale('tr', 'TR'),
        fallbackLocale: const Locale('tr', 'TR'),
        child: Builder(
          builder: (context) => ChangeNotifierProvider<SubscriptionProvider>(
            create: (_) => store = _ActivatingProvider(),
            child: MaterialApp(
              navigatorKey: navigatorKey,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PaywallScreen(),
                        ),
                      ),
                      child: const Text('open-paywall'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleFrames(tester);
    await tester.tap(find.text('open-paywall'));
    await settleFrames(tester);
    expect(find.byType(PaywallScreen), findsOneWidget);
  }

  Finder exactAlarmPrompt() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text(tr('panic_setup_exact_alarm_body')),
  );

  for (final (label, activate) in <(String, Finder Function())>[
    ('restoring', () => find.text(tr('subscription_restore_title'))),
    ('buying', () => find.text('₺399,99')),
  ]) {
    testWidgets('$label Pro asks for exact-alarm access before the paywall '
        'closes', (tester) async {
      deviceState = readinessMap(missing: <String>{'canScheduleExactAlarms'});
      await pumpOpenPaywall(tester);

      await tester.tap(activate());
      await settleFrames(tester);

      expect(
        exactAlarmPrompt(),
        findsOneWidget,
        reason: 'the first panic of a new Pro user is refused without it',
      );
      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(find.text(tr('exact_alarm_degraded_title')), findsOneWidget);

      // The user declines; the setup does not insist, and the paywall closes.
      await tester.tap(find.text(tr('exact_alarm_degraded_cancel')));
      await settleFrames(tester);
      expect(exactAlarmPrompt(), findsNothing);
      expect(find.byType(PaywallScreen), findsNothing);
      expect(platformCalls, isNot(contains('requestExactAlarmPermission')));
    });
  }

  testWidgets('accepting opens the alarm settings, and the setup goes on when '
      'the user is back', (tester) async {
    deviceState = readinessMap(
      missing: <String>{'canScheduleExactAlarms', 'alertChannelHigh'},
    );
    await pumpOpenPaywall(tester);
    await tester.tap(find.text(tr('subscription_restore_title')));
    await settleFrames(tester);

    await tester.tap(find.text(tr('exact_alarm_degraded_settings')));
    await settleFrames(tester);
    expect(platformCalls, contains('requestExactAlarmPermission'));

    // Android's settings screen covers the app...
    for (final state in const <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settleFrames(tester);
    // ...nothing is asked while the user is away...
    expect(find.text(tr('perm_alert_channel_title')), findsNothing);

    // ...the user turns the toggle on and comes back.
    deviceState = readinessMap(missing: <String>{'alertChannelHigh'});
    for (final state in const <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settleFrames(tester);

    expect(exactAlarmPrompt(), findsNothing);
    expect(
      find.text(tr('perm_alert_channel_title')),
      findsOneWidget,
      reason: 'the next capability in native order',
    );
    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  // Review 2026-11-06: the busy flags came down before the setup, and the
  // paywall is in front between its prompts. A second tap started a second
  // purchase and a second setup on top of the first.
  testWidgets('restore or purchase tapped again during the setup starts '
      'nothing', (tester) async {
    deviceState = readinessMap(missing: <String>{'canScheduleExactAlarms'});
    await pumpOpenPaywall(tester);
    await tester.tap(find.text(tr('subscription_restore_title')));
    await settleFrames(tester);

    // Accepted, but the alarm screen never covered the app: the setup waits a
    // moment for the user to leave, with the paywall in front.
    await tester.tap(find.text(tr('exact_alarm_degraded_settings')));
    await tester.pump(); // the dialog's exit transition starts here
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(PaywallScreen), findsOneWidget);

    await tester.tap(find.text(tr('subscription_restore_title')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('₺399,99'));
    await settleFrames(tester);

    expect(store.restores, 1);
    expect(store.purchases, 0);
    expect(
      exactAlarmPrompt(),
      findsNothing,
      reason: 'a second setup would ask again',
    );
    await tester.pump(const Duration(seconds: 3));
    await settleFrames(tester);
    expect(find.byType(PaywallScreen), findsNothing);
  });

  // Review 2026-11-06: the paywall closed with pop(), which removes whatever
  // is on top. A panic countdown opened from the Quick Settings tile while
  // the user was in Settings sat above the paywall, and that pop dismissed
  // it with no PIN.
  testWidgets('a panic countdown opened during the setup is not what the '
      'paywall closes', (tester) async {
    deviceState = readinessMap(missing: <String>{'canScheduleExactAlarms'});
    await pumpOpenPaywall(tester);
    await tester.tap(find.text(tr('subscription_restore_title')));
    await settleFrames(tester);
    await tester.tap(find.text(tr('exact_alarm_degraded_settings')));
    await settleFrames(tester);

    for (final state in const <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    // The Quick Settings panic tile, pressed from the notification shade.
    unawaited(
      PanicCountdownGuard.open(
        Object(),
        () => navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('live-countdown')),
          ),
        ),
      ),
    );
    for (final state in const <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settleFrames(tester);

    expect(
      find.text('live-countdown'),
      findsOneWidget,
      reason: 'the countdown was dismissed without its PIN',
    );
    expect(PanicCountdownGuard.isHeld, isTrue);
    expect(find.byType(PaywallScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('a device that is already ready closes the paywall at once', (
    tester,
  ) async {
    await pumpOpenPaywall(tester);

    await tester.tap(find.text(tr('subscription_restore_title')));
    await settleFrames(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(PaywallScreen), findsNothing);
  });
}

/// Never pumpAndSettle: a repeating animation anywhere hangs it.
Future<void> settleFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
