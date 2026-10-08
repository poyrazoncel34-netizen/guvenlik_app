import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/location_service.dart';
import 'package:guvenlik_app/core/services/rehearsal_record_service.dart';
import 'package:guvenlik_app/core/widgets/readiness_card.dart';
import 'package:guvenlik_app/domain/repositories/location_repository.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/presentation/providers/contacts_provider.dart';
import 'package:guvenlik_app/presentation/providers/home_provider.dart';
import 'package:guvenlik_app/presentation/providers/settings_provider.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:guvenlik_app/screens/home_page.dart';
import 'package:guvenlik_app/screens/main_navigation.dart';
import 'package:guvenlik_app/screens/map_page.dart';
import 'package:guvenlik_app/screens/contacts_page.dart';
import 'package:guvenlik_app/screens/countdown_screen.dart';
import 'package:guvenlik_app/screens/fake_call_screen.dart';
import 'package:guvenlik_app/screens/safety_timeline_screen.dart';
import 'package:guvenlik_app/widgets/legal_disclaimer_banner.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

class _ConfiguredPinStorage extends SecureStorage {
  @override
  Future<String?> read({required String key}) async =>
      key == SecureStorageKeys.userPin ? 'configured-hash' : null;
}

class _NoopHomeProvider extends HomeProvider {
  @override
  Future<void> initialize() async {}
}

class _TrackingHomeProvider extends _NoopHomeProvider {
  int refreshCount = 0;

  @override
  Future<void> refreshAfterContactsChanged() async {
    refreshCount++;
  }
}

class _PermissionTrackingHomeProvider extends _NoopHomeProvider {
  int locationRequestCount = 0;

  @override
  Future<String?> requestLocationPermission({BuildContext? context}) async {
    locationRequestCount++;
    return null;
  }
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

Future<void> _pumpMainNavigation(
  WidgetTester tester, {
  HomeProvider? homeProvider,
}) async {
  await pumpLocalized(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<HomeProvider>.value(
          value: homeProvider ?? _NoopHomeProvider(),
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
      child: Navigator(
        onGenerateRoute: (_) =>
            MaterialPageRoute<void>(builder: (_) => const MainNavigation()),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _homeText(String text) =>
    find.descendant(of: find.byType(HomePage), matching: find.text(text));

void _useTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<Finder> _revealHomeText(
  WidgetTester tester,
  String text, {
  bool last = false,
}) async {
  final matches = _homeText(text);
  final target = last ? matches.last : matches;
  final scrollView = find.descendant(
    of: find.byType(HomePage),
    matching: find.byType(CustomScrollView),
  );
  expect(scrollView, findsOneWidget);
  if (target.evaluate().isEmpty) {
    await tester.drag(scrollView, const Offset(0, -500));
    await tester.pump();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
  return target;
}

Finder get _mainTabStack => find.byWidgetPredicate(
  (widget) =>
      widget is IndexedStack &&
      widget.children.length == 4 &&
      widget.children.any((child) => child is MapPage),
  description: 'MainNavigation four-page IndexedStack',
);

int _selectedTab(WidgetTester tester) =>
    tester.widget<IndexedStack>(_mainTabStack).index!;

Future<void> _tapTab(WidgetTester tester, String label) async {
  final target = _tabControl(label);
  final gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 20));
  await gesture.up();
  await tester.pump();
  final fade = find.byWidgetPredicate(
    (widget) => widget is FadeTransition && widget.child is IndexedStack,
    description: 'MainNavigation tab FadeTransition',
  );
  await tester.pump(const Duration(milliseconds: 260));
  expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
}

Finder _tabControl(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.button == true &&
      widget.properties.label == label,
  description: 'bottom navigation Semantics(label: $label)',
);

Future<void> _tapWithoutCompletingTransition(
  WidgetTester tester,
  String label,
) async {
  final gesture = await tester.startGesture(
    tester.getCenter(_tabControl(label)),
  );
  await tester.pump(const Duration(milliseconds: 10));
  await gesture.up();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

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
    serviceLocator.registerSingleton<SecureStorage>(_ConfiguredPinStorage());
    serviceLocator.registerSingleton<LocationRepository>(
      _UnusedLocationRepository(),
    );
    final consent = ConsentManager();
    await consent.initialize();
    serviceLocator.registerSingleton<ConsentManager>(consent);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await serviceLocator.reset();
  });

  testWidgets('BOOT-05 MainNavigation has no overflow at 2.0x text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    await _pumpMainNavigation(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('NAV-01: home tab tap returns to the production HomePage', (
    tester,
  ) async {
    await _pumpMainNavigation(tester);
    await _tapTab(tester, 'Kişiler');
    expect(_selectedTab(tester), 2);

    await _tapTab(tester, 'Ana Sayfa');
    expect(_selectedTab(tester), 0);
  });

  testWidgets('NAV-02: map tab tap activates the production MapPage', (
    tester,
  ) async {
    await _pumpMainNavigation(tester);

    await _tapTab(tester, 'Harita');
    await tester.pump();

    expect(_selectedTab(tester), 1);
    expect(tester.widget<MapPage>(find.byType(MapPage)).isActive, isTrue);
    expect(
      find.text(
        'Bu özellik için ilgili onay gerekli. Ayarlar > Yasal Bilgiler & KVKK '
        '> Rıza Yönetimi bölümünden verebilirsin.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'NAV-02b: the hidden map requests no tiles until the map tab is opened',
    (tester) async {
      // IndexedStack keeps MapPage built while Home is shown. Its TileLayer
      // used to fetch the fallback-centre tiles from tile.openstreetmap.org
      // on every launch -- third-party traffic for a map nobody had opened,
      // and against this layer's own "only the viewport the user actively
      // views" rule. Observed on an API 35 emulator: files/osm_tiles_v1/15
      // was populated while the user never left Home.
      await _pumpMainNavigation(tester);
      expect(_selectedTab(tester), 0);
      expect(find.byType(TileLayer, skipOffstage: false), findsNothing);

      await _tapTab(tester, 'Harita');
      await tester.pump();
      expect(find.byType(TileLayer), findsOneWidget);

      // Leaving the tab keeps what was already shown; it is not torn down.
      await _tapTab(tester, 'Ana Sayfa');
      await tester.pump();
      expect(find.byType(TileLayer, skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('NAV-03: contacts tab tap selects the production ContactsPage', (
    tester,
  ) async {
    await _pumpMainNavigation(tester);

    await _tapTab(tester, 'Kişiler');

    expect(_selectedTab(tester), 2);
  });

  testWidgets('NAV-04: settings tab tap selects the production SettingsPage', (
    tester,
  ) async {
    await _pumpMainNavigation(tester);

    await _tapTab(tester, 'Ayarlar');

    expect(_selectedTab(tester), 3);
  });

  testWidgets('NAV-01..04: a second tap is ignored during tab transition', (
    tester,
  ) async {
    await _pumpMainNavigation(tester);

    await _tapWithoutCompletingTransition(tester, 'Kişiler');
    await _tapWithoutCompletingTransition(tester, 'Ayarlar');
    await tester.pump(const Duration(milliseconds: 260));

    expect(_selectedTab(tester), 2);
  });

  testWidgets(
    'HOME-02/HOME-27 production home renders empty contact and legal banner',
    (tester) async {
      await _pumpMainNavigation(tester);

      expect(find.text('Acil kişi seçilmedi'), findsOneWidget);
      expect(find.text('Dokunarak kişi seçin'), findsOneWidget);
      expect(find.byType(LegalDisclaimerBanner), findsOneWidget);
    },
  );

  testWidgets('HOME-11 onboarding close persists and removes the card', (
    tester,
  ) async {
    await _pumpMainNavigation(tester);
    expect(find.text('3 adımda hazır olun'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();

    expect(find.text('3 adımda hazır olun'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        HomeProvider.onboardingKey,
      ),
      isTrue,
    );
  });

  testWidgets(
    'HOME-12 onboarding contact step pushes production ContactsPage',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpMainNavigation(tester);
      final action = find.text('Acil kişi seçin');
      expect(action, findsOneWidget);
      await tester.tap(action);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ContactsPage), findsOneWidget);
    },
  );

  testWidgets(
    'HOME-01 contact chip pushes ContactsPage and refreshes on return',
    (tester) async {
      final home = _TrackingHomeProvider();
      await _pumpMainNavigation(tester, homeProvider: home);

      await tester.tap(find.text('Dokunarak kişi seçin'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ContactsPage), findsOneWidget);
      expect(home.refreshCount, 0);

      Navigator.of(tester.element(find.byType(ContactsPage))).pop();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ContactsPage), findsNothing);
      expect(home.refreshCount, 1);
    },
  );

  testWidgets('HOME-03 readiness emergency-contact chip pushes ContactsPage', (
    tester,
  ) async {
    await _pumpMainNavigation(tester);
    final action = find.descendant(
      of: find.byType(ReadinessCard),
      matching: find.text('Acil kişi'),
    );
    expect(action, findsOneWidget);

    await tester.tap(action);
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(ContactsPage), findsOneWidget);
  });

  testWidgets(
    'HOME-07 readiness contacts chip opens the production ContactsPage',
    (tester) async {
      await _pumpMainNavigation(tester);
      final action = find.descendant(
        of: find.byType(ReadinessCard),
        matching: find.text('Rehber'),
      );
      expect(action, findsOneWidget);

      await tester.tap(action);
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(ContactsPage), findsOneWidget);
      expect(find.text('Rehber İzni Gerekli'), findsNothing);
    },
  );

  testWidgets(
    'HOME-10 readiness rehearsal runs production Test Mode to completion',
    (tester) async {
      _useTallView(tester);
      await _pumpMainNavigation(tester);
      final action = find.descendant(
        of: find.byType(ReadinessCard),
        matching: find.text(
          'Henüz prova yapmadın. Test Modu gerçek arama yapmaz — dokunup deneyebilirsin.',
        ),
      );
      expect(action, findsOneWidget);

      await tester.tap(action);
      await tester.pump();
      expect(find.byType(CountdownScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(CountdownScreen), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getInt(
          RehearsalRecordService.prefLastRehearsalAt,
        ),
        isNotNull,
      );
    },
  );

  testWidgets('HOME-14 standalone Test Mode button runs production countdown', (
    tester,
  ) async {
    _useTallView(tester);
    await _pumpMainNavigation(tester);
    final action = await _revealHomeText(
      tester,
      'Test Modu (gerçek arama yapılmaz)',
    );

    await tester.tap(action);
    await tester.pump();
    expect(find.byType(CountdownScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(CountdownScreen), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getInt(
        RehearsalRecordService.prefLastRehearsalAt,
      ),
      isNotNull,
    );
  });

  testWidgets('HOME-24/25 rationale Later cancels and Allow continues', (
    tester,
  ) async {
    final home = _PermissionTrackingHomeProvider();
    await tester.runAsync(
      () => serviceLocator<ConsentManager>().grantConsent(
        ConsentRecord.typeLocation,
      ),
    );
    await _pumpMainNavigation(tester, homeProvider: home);
    final locationChip = find.descendant(
      of: find.byType(ReadinessCard),
      matching: find.text('Konum'),
    );
    expect(locationChip, findsOneWidget);

    await tester.tap(locationChip);
    await tester.pump();
    expect(find.text('Konum İzni Gerekli'), findsOneWidget);
    await tester.tap(find.text('Şimdi Değil'));
    await tester.pump();
    expect(home.locationRequestCount, 0);

    await tester.tap(locationChip);
    await tester.pump();
    await tester.tap(find.text('İzin Ver'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(home.locationRequestCount, 1);
  });

  testWidgets('HOME-19 contacts quick action pushes production ContactsPage', (
    tester,
  ) async {
    _useTallView(tester);
    await _pumpMainNavigation(tester);
    final action = await _revealHomeText(tester, 'Rehber', last: true);
    expect(action, findsOneWidget);

    await tester.tap(action);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ContactsPage), findsOneWidget);
  });

  testWidgets('HOME-20 history quick action pushes SafetyTimelineScreen', (
    tester,
  ) async {
    late Database db;
    await tester.runAsync(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await LocalDatabaseService.createSchema(db);
    });
    serviceLocator.registerSingleton<LocalDatabaseService>(
      _MemoryDatabaseService(db),
    );
    addTearDown(db.close);
    _useTallView(tester);
    await _pumpMainNavigation(tester);
    final action = await _revealHomeText(tester, 'Plan ve Geçmiş');
    expect(action, findsOneWidget);

    await tester.tap(action);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SafetyTimelineScreen), findsOneWidget);
  });

  testWidgets(
    'HOME-23 quick action cancel restores scale and suppresses action',
    (tester) async {
      _useTallView(tester);
      await _pumpMainNavigation(tester);
      final action = await _revealHomeText(tester, 'Rehber', last: true);
      final scale = find.ancestor(
        of: action,
        matching: find.byType(ScaleTransition),
      );
      final detector = find.ancestor(
        of: action,
        matching: find.byType(GestureDetector),
      );
      expect(scale, findsOneWidget);
      expect(detector, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(detector));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 130));
      expect(
        tester.widget<ScaleTransition>(scale).scale.value,
        closeTo(0.95, 0.001),
      );

      await gesture.moveBy(const Offset(300, 0));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        tester.widget<ScaleTransition>(scale).scale.value,
        closeTo(1, 0.001),
      );
      expect(find.byType(ContactsPage), findsNothing);

      await tester.tap(action);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ContactsPage), findsOneWidget);
    },
  );

  testWidgets('HOME-15/FKC-01/FKC-02 consent gates then opens fake call now', (
    tester,
  ) async {
    _useTallView(tester);
    await _pumpMainNavigation(tester);
    final action = await _revealHomeText(tester, 'Sahte Çağrı');

    await tester.tap(action);
    await tester.pump();
    expect(find.text('Şimdi'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);

    final consent = serviceLocator<ConsentManager>();
    await tester.runAsync(
      () => consent.grantConsent(ConsentRecord.typeFakeCall),
    );
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pref_fake_call_warned', true);
    });
    ScaffoldMessenger.of(
      tester.element(find.byType(HomePage)),
    ).hideCurrentSnackBar();
    await tester.pump();

    await tester.tap(action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Şimdi'), findsOneWidget);
    await tester.tap(find.text('Şimdi'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FakeCallScreen), findsOneWidget);
  });
}
