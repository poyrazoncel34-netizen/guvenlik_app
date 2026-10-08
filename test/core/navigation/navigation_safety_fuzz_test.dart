// Stateful, seeded random user sequences over the REAL navigation-safety stack.
//
// The defects fixed alongside this file (route-agnostic pops and replacements,
// a lock that could be popped from under the user, links and the lock landing
// on a live panic countdown) were each found at the INTERSECTION of two
// features, in an order no single-feature test walked. This harness drives the
// production pieces together -- MainNavigation (external-entry routing),
// AppLifecycleHandler (the resume PIN lock), PanicCountdownGuard, OwnRoute and
// EmergencyCallScreen -- with random but reproducible action sequences, and
// checks safety invariants after EVERY step:
//
//   I1  at most one countdown route; the guard is held iff one is on the stack
//   I2  while the lock is owed, no app-content route is the visible one
//   I3  no link destination ever sits above the lock or above a countdown
//   I4  no countdown is left on the stack after it finished (dead countdown)
//   I5  no framework exception
//   I6  the lock leaves the stack only through a verified unlock or a wipe
//   I7  the lock never sits above a countdown that is still running
//   I8  a countdown never leaves the stack before it finished
//
// The countdown itself is a stub that makes exactly the navigation calls the
// real CountdownScreen makes (OwnRoute.replace at the deadline, OwnRoute.pop
// on a verified cancel): the real screen's ten real-time seconds would make a
// fuzz run impractical, and its navigation is pinned separately in
// test/screens/countdown_route_scoped_navigation_test.dart.
//
// Reproduce a failure:  FUZZ_SEED=<seed printed in the failure> flutter test <this file>
// Longer local run:     FUZZ_SCALE=10 flutter test <this file>

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/navigation/app_navigator.dart';
import 'package:guvenlik_app/core/navigation/own_route.dart';
import 'package:guvenlik_app/core/navigation/pending_destination_service.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/app_lifecycle_handler.dart';
import 'package:guvenlik_app/core/services/app_reset_state_registry.dart';
import 'package:guvenlik_app/core/services/call_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/location_service.dart';
import 'package:guvenlik_app/core/services/panic_countdown_guard.dart';
import 'package:guvenlik_app/domain/repositories/location_repository.dart';
import 'package:guvenlik_app/presentation/providers/contacts_provider.dart';
import 'package:guvenlik_app/presentation/providers/home_provider.dart';
import 'package:guvenlik_app/presentation/providers/settings_provider.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:guvenlik_app/screens/app_unlock_screen.dart';
import 'package:guvenlik_app/screens/emergency_call_screen.dart';
import 'package:guvenlik_app/screens/main_navigation.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _countdownName = 'fuzz/countdown';
const _callName = 'fuzz/call-result';
const _detailName = 'fuzz/detail';
const _fakeCallName = 'fuzz/fake-call';

class _PinStorage extends SecureStorage {
  bool absent = false;

  @override
  Future<String?> read({required String key}) async {
    if (key != SecureStorageKeys.userPin) return null;
    return absent ? null : 'configured-hash';
  }

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<void> deleteAll() async {}
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

/// The navigator's history, mirrored from observer callbacks, plus every
/// route that LEFT it since the last check.
class _Stack extends NavigatorObserver {
  final List<Route<dynamic>> routes = <Route<dynamic>>[];
  final List<String> departures = <String>[];

  void _left(Route<dynamic> route) {
    if (routes.isEmpty) return;
    final kind = _kind(route, routes.first);
    if (kind == 'countdown') {
      final live = _StubCountdownState.live;
      departures.add(live != null && !live.finished
          ? 'unfinished-countdown'
          : 'countdown');
    } else {
      departures.add(kind);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _left(route);
    routes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _left(route);
    routes.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (oldRoute != null && index >= 0) _left(oldRoute);
    if (index >= 0 && newRoute != null) {
      routes[index] = newRoute;
    } else if (newRoute != null) {
      routes.add(newRoute);
    }
  }
}

String _kind(Route<dynamic> route, Route<dynamic> first) {
  if (identical(route, first)) return 'home';
  if (AppLifecycleHandler.isLockRoute(route)) return 'lock';
  if (route is DialogRoute) return 'dialog';
  return switch (route.settings.name) {
    _countdownName => 'countdown',
    _callName => 'call',
    _detailName => 'detail',
    _fakeCallName => 'fakecall',
    _ => 'external',
  };
}

/// Exactly the navigation the real CountdownScreen performs.
class _StubCountdown extends StatefulWidget {
  const _StubCountdown();

  @override
  State<_StubCountdown> createState() => _StubCountdownState();
}

class _StubCountdownState extends State<_StubCountdown> {
  static _StubCountdownState? live;
  bool finished = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    live = this;
    // Like the real one, it reaches its deadline on its own after ten seconds.
    _clock = Timer(const Duration(seconds: 10), () {
      if (mounted && !finished) deadline();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    if (identical(live, this)) live = null;
    super.dispose();
  }

  void deadline() {
    finished = true;
    OwnRoute.replace(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: _callName),
        builder: (_) => EmergencyCallScreen(
          name: 'Acil Kisi',
          phone: '+905551112233',
          callResult: EmergencyCallResult.requested('+905551112233'),
        ),
      ),
    );
  }

  void cancelWithPin() {
    finished = true;
    OwnRoute.pop(context);
  }

  /// Native reports the session already cancelled when the deadline is
  /// claimed: the countdown closes itself -- possibly while covered.
  void nativeCancelledAtDeadline() {
    finished = true;
    OwnRoute.pop(context);
  }

  @override
  Widget build(BuildContext context) => const PopScope(
    canPop: false,
    child: Scaffold(body: Center(child: Text('COUNTDOWN'))),
  );
}

class _Fuzz {
  _Fuzz(this.tester, this.stack, this.storage, this.random, this.seed);

  final WidgetTester tester;
  final _Stack stack;
  final _PinStorage storage;
  final Random random;
  final int seed;
  final List<String> log = <String>[];

  /// Model: a long-background resume with a PIN present owes a lock until a
  /// verified unlock or a completed wipe.
  bool lockOwed = false;

  /// A correct PIN typed on the lock whose verification has not finished
  /// (PBKDF2 takes about half a second): other things can happen meanwhile.
  bool unlockVerifying = false;

  /// Set by the action that may legitimately take the lock down.
  bool lockMayLeave = false;

  NavigatorState get _navigator => rootNavigatorKey.currentState!;
  Route<dynamic> get _top => stack.routes.last;
  String get _topKind => _kind(_top, stack.routes.first);
  List<String> get _kinds =>
      stack.routes.map((r) => _kind(r, stack.routes.first)).toList();

  Future<void> settle() async {
    // Screens reached by a step (the timeline via a link) do real ffi I/O,
    // which never progresses inside the fake-async zone.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> step() async {
    final actions = <String, Future<void> Function()>{
      'quickPanic': () async {
        PanicCountdownGuard.open(
          Object(),
          () => _navigator.push<void>(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: _countdownName),
              builder: (_) => const _StubCountdown(),
            ),
          ),
        );
      },
      'countdownDeadline': () async {
        final live = _StubCountdownState.live;
        if (live != null && live.mounted && !live.finished) live.deadline();
      },
      'nativeCancelledAtDeadline': () async {
        final live = _StubCountdownState.live;
        if (live != null && live.mounted && !live.finished) {
          live.nativeCancelledAtDeadline();
        }
      },
      'cancelWithPin': () async {
        final live = _StubCountdownState.live;
        final route = live == null ? null : ModalRoute.of(live.context);
        // The keypad is only reachable while the countdown is on top.
        if (live != null && !live.finished && (route?.isCurrent ?? false)) {
          live.cancelWithPin();
        }
      },
      'callScreenEnd': () async {
        if (_topKind != 'call') return;
        final end = find.bySemanticsLabel('emergency_call_end'.tr());
        if (end.evaluate().isNotEmpty) await tester.tap(end.first);
      },
      'dismissDialog': () async {
        if (_topKind != 'dialog') return;
        final dismiss = find.text('emergency_dismiss'.tr());
        if (dismiss.evaluate().isNotEmpty) await tester.tap(dismiss.last);
      },
      'link': () async {
        final slug = const ['timeline', 'timeline', 'home', 'settings'][random
            .nextInt(4)];
        PendingDestinationService.instance.submitUri(
          Uri.parse('korubeni://open/$slug'),
        );
      },
      'longBackground': () async {
        if (!storage.absent) lockOwed = true;
        AppLifecycleHandler.instance.pausedAtForTest = DateTime.now().subtract(
          const Duration(seconds: AppLifecycleHandler.lockAfterSeconds + 5),
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        unawaited(AppLifecycleHandler.instance.onResumed());
      },
      'shortBackground': () async {
        AppLifecycleHandler.instance.pausedAtForTest = DateTime.now().subtract(
          const Duration(seconds: 5),
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        unawaited(AppLifecycleHandler.instance.onResumed());
      },
      'typeCorrectPin': () async {
        if (_topKind == 'lock') unlockVerifying = true;
      },
      'pinVerified': () async {
        if (!unlockVerifying) return;
        unlockVerifying = false;
        final lock = find.byType(AppUnlockScreen, skipOffstage: false);
        if (lock.evaluate().isEmpty) return;
        lockMayLeave = true;
        tester.widget<AppUnlockScreen>(lock.last).onUnlocked();
        lockOwed = false;
      },
      'back': () async {
        await _navigator.maybePop();
      },
      'openDetail': () async {
        if (_topKind != 'home') return;
        unawaited(
          _navigator.push<void>(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: _detailName),
              builder: (_) => const Scaffold(body: Text('DETAIL')),
            ),
          ),
        );
      },
      'fakeCallNotification': () async {
        unawaited(
          _navigator.push<void>(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: _fakeCallName),
              builder: (_) => const Scaffold(body: Text('FAKE CALL')),
            ),
          ),
        );
      },
      'forgotPinWipe': () async {
        if (_topKind != 'lock') return;
        storage.absent = true;
        await AppResetStateRegistry.resetAll();
        lockMayLeave = true;
        _navigator.popUntil((route) => route.isFirst);
        lockOwed = false;
        unlockVerifying = false;
      },
      'setPinAgain': () async {
        storage.absent = false;
      },
    };
    const weights = <String, int>{
      'quickPanic': 6,
      'countdownDeadline': 5,
      'cancelWithPin': 4,
      'nativeCancelledAtDeadline': 2,
      'callScreenEnd': 4,
      'dismissDialog': 2,
      'link': 6,
      'longBackground': 5,
      'shortBackground': 2,
      'typeCorrectPin': 4,
      'pinVerified': 4,
      'back': 5,
      'openDetail': 3,
      'fakeCallNotification': 1,
      'forgotPinWipe': 1,
      'setPinAgain': 1,
    };
    final total = weights.values.reduce((a, b) => a + b);
    var pick = random.nextInt(total);
    final name = weights.entries.firstWhere((entry) {
      pick -= entry.value;
      return pick < 0;
    }).key;
    log.add(name);
    lockMayLeave = false;
    await actions[name]!();
    await settle();
    _checkInvariants();
    stack.departures.clear();
  }

  void _fail(String invariant, String detail) {
    fail(
      '$invariant violated (FUZZ_SEED=$seed, step ${log.length}): $detail\n'
      'stack (bottom->top): $_kinds\n'
      'actions: ${log.join(' > ')}',
    );
  }

  void _checkInvariants() {
    final exception = tester.takeException();
    if (exception != null) _fail('I5', 'framework exception: $exception');

    final kinds = _kinds;
    final countdowns = kinds.where((k) => k == 'countdown').length;
    if (countdowns > 1) _fail('I1', '$countdowns countdown routes');
    if (PanicCountdownGuard.isHeld != (countdowns == 1)) {
      _fail('I1', 'guard held=${PanicCountdownGuard.isHeld}, routes=$countdowns');
    }

    final live = _StubCountdownState.live;
    if (countdowns == 1 && live != null && live.finished) {
      _fail('I4', 'a finished countdown is still on the stack');
    }

    const noPinSurfaces = {'lock', 'countdown', 'call', 'dialog', 'fakecall'};
    if (lockOwed && !noPinSurfaces.contains(_topKind)) {
      _fail('I2', 'app content "$_topKind" is visible while the lock is owed');
    }

    for (final departed in stack.departures) {
      if (departed == 'lock' && !lockMayLeave) {
        _fail('I6', 'the lock left the stack without an unlock or a wipe');
      }
      if (departed == 'unfinished-countdown') {
        _fail('I8', 'a running countdown left the stack (armed, no cancel UI)');
      }
    }

    final lockIndex = kinds.indexOf('lock');
    final countdownIndex = kinds.indexOf('countdown');
    if (lockIndex > countdownIndex &&
        countdownIndex >= 0 &&
        !(live?.finished ?? true)) {
      _fail('I7', 'the lock covers a running countdown');
    }
    for (var i = 0; i < kinds.length; i++) {
      if (kinds[i] != 'external') continue;
      if (lockIndex >= 0 && i > lockIndex) {
        _fail('I3', 'a link destination sits above the lock');
      }
      if (countdownIndex >= 0 && i > countdownIndex) {
        _fail('I3', 'a link destination sits above a live countdown');
      }
    }
  }
}

Future<_Stack> _pumpApp(WidgetTester tester) async {
  final stack = _Stack();
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
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              navigatorObservers: <NavigatorObserver>[stack],
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
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  return stack;
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    AppLifecycleHandler.instance.resetForTest();
    PendingDestinationService.instance.clear();
    PanicCountdownGuard.resetForTesting();
    await serviceLocator.reset();
  });

  final pinned = int.tryParse(Platform.environment['FUZZ_SEED'] ?? '');
  final scale = int.tryParse(Platform.environment['FUZZ_SCALE'] ?? '') ?? 1;
  const baseSeed = 20261007;
  // (count, actions per sequence): short, medium and long runs.
  final plan = pinned != null
      ? <(int, int)>[(1, 120)]
      : <(int, int)>[(12 * scale, 10), (10 * scale, 40), (4 * scale, 120)];

  var index = 0;
  for (final (count, length) in plan) {
    for (var i = 0; i < count; i++) {
      final seed = pinned ?? baseSeed + index++;
      testWidgets('seed $seed: $length random user actions keep the '
          'navigation-safety invariants', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        final stack = await _pumpApp(tester);
        expect(find.byType(MainNavigation), findsOneWidget);
        final fuzz = _Fuzz(tester, stack, storage, Random(seed), seed);
        for (var stepIndex = 0; stepIndex < length; stepIndex++) {
          await fuzz.step();
        }
        // Drain: let any pending lock, link or fail-safe timer run out.
        await tester.pump(const Duration(seconds: 70));
        await fuzz.settle();
        fuzz._checkInvariants();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 6));
        // Let screens' in-flight ffi reads finish before tearDown closes the
        // database under them.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump(const Duration(seconds: 6));
      });
    }
  }
}
