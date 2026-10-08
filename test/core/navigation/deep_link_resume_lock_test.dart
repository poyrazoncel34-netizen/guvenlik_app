// A parked external destination must never be routed ABOVE the resume lock.
//
// Reproduced on an API 35 emulator (commit eda8304, play debug): background
// the app > 120 s, return (the re-auth lock appears), press HOME, then
// `adb shell am start -a android.intent.action.VIEW -d korubeni://open/timeline`.
// The safety timeline opened OVER the lock, readable and editable without the
// PIN. The lock is a route pushed above `/`; MainNavigation, which consumes
// parked links, lives under it and pushed straight onto the same Navigator.
//
// `deep_link_test.dart` "LOCKED: nothing collects until MainNavigation
// exists" only reasoned about the STARTUP lock, where MainNavigation does not
// exist yet. The resume lock is the other one.

import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/navigation/app_destination.dart';
import 'package:guvenlik_app/core/navigation/app_navigator.dart';
import 'package:guvenlik_app/core/navigation/destination_router.dart';
import 'package:guvenlik_app/core/navigation/pending_destination_service.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/app_lifecycle_handler.dart';
import 'package:guvenlik_app/core/services/panic_countdown_guard.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/location_service.dart';
import 'package:guvenlik_app/domain/repositories/location_repository.dart';
import 'package:guvenlik_app/presentation/providers/contacts_provider.dart';
import 'package:guvenlik_app/presentation/providers/home_provider.dart';
import 'package:guvenlik_app/presentation/providers/settings_provider.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:guvenlik_app/screens/app_unlock_screen.dart';
import 'package:guvenlik_app/screens/check_in_screen.dart';
import 'package:guvenlik_app/screens/main_navigation.dart';
import 'package:guvenlik_app/screens/safety_timeline_screen.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A configured PIN whose read can be held open to model a slow keystore.
class _PinStorage extends SecureStorage {
  Completer<void>? gate;
  bool absent = false;

  @override
  Future<String?> read({required String key}) async {
    if (key != SecureStorageKeys.userPin) return null;
    final pending = gate;
    if (pending != null) await pending.future;
    return absent ? null : 'configured-hash';
  }
}

/// A verified subscriber whose store answer is held open until released.
class _GatedSubscription extends SubscriptionProvider {
  final Completer<void> resolveGate = Completer<void>();
  static final SubscriptionAccessState _pro = SubscriptionAccessState(
    status: SubscriptionAccessStatus.verifiedPro,
    lastVerifiedPro: true,
    lastVerifiedProAt: DateTime.now(),
  );

  @override
  SubscriptionAccessState get access => _pro;

  @override
  Future<void> ensureOfflineGraceLoaded() async {}

  @override
  Future<SubscriptionAccessState> resolveAccess() async {
    await resolveGate.future;
    return _pro;
  }
}

class _NoopHomeProvider extends HomeProvider {
  @override
  Future<void> initialize() async {}
}

class _NoopContactsProvider extends ContactsProvider {
  @override
  Future<void> initialize() async {}
}

class _UnusedLocationRepository implements LocationRepository {
  @override
  LatLng? get lastKnownPosition => null;

  @override
  Future<LocationResult> getCurrentLocation({bool highAccuracy = true}) =>
      throw StateError('location must stay behind the consent gate');

  @override
  Future<LocationResult> getLastKnownLocation() =>
      throw StateError('location must stay behind the consent gate');

  @override
  Stream<Position>? getPositionStream({
    bool highAccuracy = true,
    int distanceFilter = 10,
  }) => null;

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;
}

class _MemoryDatabaseService extends LocalDatabaseService {
  _MemoryDatabaseService(this.db);

  final Database db;

  @override
  Future<Database> get database async => db;
}

Future<void> _settle(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr', 'TR')],
        path: 'assets/translations',
        startLocale: const Locale('tr', 'TR'),
        fallbackLocale: const Locale('tr', 'TR'),
        child: Builder(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider<HomeProvider>.value(
                value: _NoopHomeProvider(),
              ),
              ChangeNotifierProvider<ContactsProvider>.value(
                value: _NoopContactsProvider(),
              ),
              ChangeNotifierProvider<SettingsProvider>(
                create: (_) => SettingsProvider(),
              ),
              ChangeNotifierProvider<SubscriptionProvider>(
                create: (_) => SubscriptionProvider(),
              ),
            ],
            // Production shape: MainNavigation sits in `/` of the ROOT
            // Navigator, the same Navigator the resume lock is pushed onto.
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: const MainNavigation(),
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await _settle(tester);
}

/// The real resume path: a background longer than the lock threshold.
void _backgroundPastThreshold() {
  AppLifecycleHandler.instance.pausedAtForTest = DateTime.now().subtract(
    const Duration(seconds: AppLifecycleHandler.lockAfterSeconds + 5),
  );
}

void _parkTimelineLink() {
  PendingDestinationService.instance.submitUri(
    Uri.parse('korubeni://open/timeline'),
  );
}

void _unlock(WidgetTester tester) {
  tester.widget<AppUnlockScreen>(find.byType(AppUnlockScreen)).onUnlocked();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late _PinStorage storage;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => Directory.systemTemp.path,
        );
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.prefNotifications: false,
      'battery_optimization_wizard_seen': true,
    });
    PackageInfo.setMockInitialValues(
      appName: 'KoruBeni',
      packageName: 'com.poyrazoncel.korubeni',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await EasyLocalization.ensureInitialized();
    await serviceLocator.reset();
    storage = _PinStorage();
    serviceLocator.registerSingleton<SecureStorage>(storage);
    serviceLocator.registerSingleton<LocationRepository>(
      _UnusedLocationRepository(),
    );
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: LocalDatabaseService.databaseVersion,
        onCreate: (db, _) => LocalDatabaseService.createSchema(db),
      ),
    );
    addTearDown(db.close);
    serviceLocator.registerSingleton<LocalDatabaseService>(
      _MemoryDatabaseService(db),
    );
    for (final name in const <String>[
      'dev.fluttercommunity.plus/connectivity',
      'dev.fluttercommunity.plus/connectivity_status',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel(name),
            (call) async => call.method == 'check' ? <String>['wifi'] : null,
          );
    }
    final consent = ConsentManager();
    await consent.initialize();
    serviceLocator.registerSingleton<ConsentManager>(consent);
    AppLifecycleHandler.instance.resetForTest();
    PendingDestinationService.instance.clear();
    PanicCountdownGuard.resetForTesting();
  });

  tearDown(() async {
    PanicCountdownGuard.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    AppLifecycleHandler.instance.resetForTest();
    PendingDestinationService.instance.clear();
    await serviceLocator.reset();
  });

  testWidgets('a link arriving while the resume lock is up waits for unlock', (
    tester,
  ) async {
    await _pumpApp(tester);
    expect(find.byType(MainNavigation), findsOneWidget);

    _backgroundPastThreshold();
    unawaited(AppLifecycleHandler.instance.onResumed());
    await _settle(tester, rounds: 5);
    expect(find.byType(AppUnlockScreen), findsOneWidget);
    expect(AppLifecycleHandler.instance.lockActive.value, isTrue);

    _parkTimelineLink();
    await _settle(tester);

    expect(
      find.byType(SafetyTimelineScreen),
      findsNothing,
      reason: 'the timeline must not open above the PIN lock',
    );
    expect(find.byType(AppUnlockScreen), findsOneWidget);
    expect(
      PendingDestinationService.instance.hasPending,
      isTrue,
      reason: 'the link is kept for after unlock, not dropped',
    );

    _unlock(tester);
    await _settle(tester);
    expect(AppLifecycleHandler.instance.lockActive.value, isFalse);
    expect(find.byType(AppUnlockScreen), findsNothing);
    expect(find.byType(SafetyTimelineScreen), findsOneWidget);
    expect(PendingDestinationService.instance.hasPending, isFalse);
  });

  testWidgets(
    'a link collected while the lock decision is still reading the PIN waits',
    (tester) async {
      await _pumpApp(tester);
      storage.gate = Completer<void>();

      _backgroundPastThreshold();
      unawaited(AppLifecycleHandler.instance.onResumed());
      // Raised synchronously, before the PIN read finishes: this is what
      // closes the resume race against MainNavigation's own resume handler.
      expect(AppLifecycleHandler.instance.lockActive.value, isTrue);

      _parkTimelineLink();
      await _settle(tester, rounds: 5);
      expect(find.byType(SafetyTimelineScreen), findsNothing);

      storage.gate!.complete();
      await _settle(tester);
      expect(find.byType(AppUnlockScreen), findsOneWidget);
      expect(find.byType(SafetyTimelineScreen), findsNothing);

      _unlock(tester);
      await _settle(tester);
      expect(find.byType(AppUnlockScreen), findsNothing);
      expect(find.byType(SafetyTimelineScreen), findsOneWidget);
    },
  );

  testWidgets('a PIN read that never returns still shows the lock (fail-closed)', (
    tester,
  ) async {
    await _pumpApp(tester);
    storage.gate = Completer<void>(); // never completed

    _backgroundPastThreshold();
    unawaited(AppLifecycleHandler.instance.onResumed());
    expect(AppLifecycleHandler.instance.lockActive.value, isTrue);
    await tester.pump(AppLifecycleHandler.pinReadTimeout);
    await _settle(tester, rounds: 5);

    // An unreadable PIN is never evidence that there is none: the lock shows,
    // and the flag follows the route instead of hanging on the read forever.
    expect(find.byType(AppUnlockScreen), findsOneWidget);
    _parkTimelineLink();
    await _settle(tester, rounds: 3);
    expect(find.byType(SafetyTimelineScreen), findsNothing);
    tester.widget<AppUnlockScreen>(find.byType(AppUnlockScreen)).onUnlocked();
    await _settle(tester);
    expect(AppLifecycleHandler.instance.lockActive.value, isFalse);
    expect(find.byType(SafetyTimelineScreen), findsOneWidget);
    // Release the stalled read so no timer outlives the test.
    storage.gate!.complete();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'a lock that rises during the subscription gate defers a gated link',
    (tester) async {
      // Check-In is the one Pro destination, so the router awaits the store
      // before pushing. The lock decision starts during that await.
      final subscription = _GatedSubscription();
      late BuildContext routerContext;
      await tester.pumpWidget(
        ChangeNotifierProvider<SubscriptionProvider>.value(
          value: subscription,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: Builder(
              builder: (context) {
                routerContext = context;
                return const Scaffold(body: Text('home'));
              },
            ),
          ),
        ),
      );
      storage.gate = Completer<void>();

      final outcome = DestinationRouter.route(
        routerContext,
        AppDestination.checkIn,
        selectTab: (_) {},
      );
      await tester.pump();
      _backgroundPastThreshold();
      unawaited(AppLifecycleHandler.instance.onResumed());
      expect(AppLifecycleHandler.instance.lockActive.value, isTrue);

      DestinationRouteOutcome? result;
      unawaited(outcome.then((value) => result = value));
      subscription.resolveGate.complete();
      await tester.pump();
      await tester.pump();
      // Not awaited directly: a router that pushed would wait for the pop.
      expect(find.byType(CheckInScreen), findsNothing);
      expect(result, DestinationRouteOutcome.deferredByLock);
      expect(rootNavigatorKey.currentState!.canPop(), isFalse);

      // Let the stalled lock decision finish without a lock route.
      storage.absent = true;
      storage.gate!.complete();
      await tester.pump(const Duration(seconds: 3));
      expect(AppLifecycleHandler.instance.lockActive.value, isFalse);
    },
  );

  // A link pushed over a live panic countdown hid its PIN-cancel pad, and at
  // the deadline the countdown's own navigation then hit the LINK's route
  // (reproduced on an API 35 emulator with Test Mode + korubeni://open/timeline:
  // the rehearsal was left stuck at zero). Links wait for the countdown.
  testWidgets('a link arriving during a live panic countdown waits until it '
      'closes', (tester) async {
    await _pumpApp(tester);
    final opened = PanicCountdownGuard.open(
      Object(),
      () => rootNavigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('COUNTDOWN'))),
        ),
      ),
    );
    expect(opened, isNotNull);
    await _settle(tester, rounds: 3);

    _parkTimelineLink();
    await _settle(tester);

    expect(
      find.byType(SafetyTimelineScreen),
      findsNothing,
      reason: 'the timeline opened over the live countdown (A-06)',
    );
    expect(find.text('COUNTDOWN'), findsOneWidget);
    expect(PendingDestinationService.instance.hasPending, isTrue);

    rootNavigatorKey.currentState!.pop();
    await _settle(tester);
    expect(find.byType(SafetyTimelineScreen), findsOneWidget);
    expect(PendingDestinationService.instance.hasPending, isFalse);
  });

  testWidgets(
    'a countdown that opens during the subscription gate defers a gated link',
    (tester) async {
      final subscription = _GatedSubscription();
      late BuildContext routerContext;
      await tester.pumpWidget(
        ChangeNotifierProvider<SubscriptionProvider>.value(
          value: subscription,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: Builder(
              builder: (context) {
                routerContext = context;
                return const Scaffold(body: Text('home'));
              },
            ),
          ),
        ),
      );

      final outcome = DestinationRouter.route(
        routerContext,
        AppDestination.checkIn,
        selectTab: (_) {},
      );
      await tester.pump();
      // A volume-key panic lands while the store answer is pending.
      PanicCountdownGuard.open(
        Object(),
        () => rootNavigatorKey.currentState!.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('COUNTDOWN')),
          ),
        ),
      );
      await tester.pump();

      DestinationRouteOutcome? result;
      unawaited(outcome.then((value) => result = value));
      subscription.resolveGate.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byType(CheckInScreen), findsNothing);
      expect(result, DestinationRouteOutcome.deferredByCountdown);
    },
  );

  testWidgets('a resume while the lock is up clears the background clock', (
    tester,
  ) async {
    await _pumpApp(tester);
    _backgroundPastThreshold();
    unawaited(AppLifecycleHandler.instance.onResumed());
    await _settle(tester, rounds: 5);
    expect(find.byType(AppUnlockScreen), findsOneWidget);

    // Background again while locked, then return: the stamp must not survive
    // into the unlocked session, or a later 2 s background re-locks at once.
    AppLifecycleHandler.instance.onPaused();
    unawaited(AppLifecycleHandler.instance.onResumed());
    await _settle(tester, rounds: 2);
    expect(AppLifecycleHandler.instance.pausedAt, isNull);
    _unlock(tester);
    await _settle(tester);
    expect(AppLifecycleHandler.instance.lockActive.value, isFalse);
  });
}
