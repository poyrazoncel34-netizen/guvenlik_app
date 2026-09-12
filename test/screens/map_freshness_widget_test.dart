import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/services/connectivity_service.dart';
import 'package:guvenlik_app/core/services/location_service.dart';
import 'package:guvenlik_app/data/repositories/location_repository_impl.dart';
import 'package:guvenlik_app/domain/repositories/location_repository.dart';
import 'package:guvenlik_app/screens/map_page.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Consent extends ConsentManager {
  @override
  bool isGranted(String consentType) => true;
}

class _Assets extends AssetLoader {
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _LocationPlatform extends GeolocatorPlatform {
  Position? previous;
  Position? current;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => previous;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (current != null) return current!;
    throw TimeoutException('synthetic timeout');
  }
}

Position _measurement() => Position(
  latitude: 40,
  longitude: 29,
  timestamp: DateTime(2020, 1, 2, 3, 4),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _LocationPlatform platform;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await serviceLocator.reset();
    serviceLocator.registerSingleton<ConsentManager>(_Consent());
    serviceLocator.registerSingleton<LocationRepository>(
      LocationRepositoryImpl(LocationService.forTesting()),
    );
    platform = _LocationPlatform();
    GeolocatorPlatform.instance = platform;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['none'],
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
    await ConnectivityService.instance.initialize();
  });
  tearDown(() => serviceLocator.reset());

  Future<void> mount(WidgetTester tester, double scale) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr', 'TR')],
        path: 'assets/translations',
        assetLoader: _Assets(),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 640),
                disableAnimations: true,
                textScaler: TextScaler.linear(scale),
              ),
              child: const MapPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'old measurement + timeout renders old timestamp at scale $scale',
      (tester) async {
        platform.previous = _measurement();
        await mount(tester, scale);
        expect(find.text('map_fallback_location'.tr()), findsOneWidget);
        expect(find.textContaining('2.1.2020'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'no measurement shows unavailable without a fabricated timestamp',
    (tester) async {
      await mount(tester, 1);
      expect(find.text('map_location_unavailable'.tr()), findsWidgets);
      expect(find.text('map_fallback_location'.tr()), findsNothing);
      expect(find.textContaining('2020'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('current fix clears the stale warning on the real map page', (
    tester,
  ) async {
    platform.previous = _measurement();
    platform.current = _measurement();
    await mount(tester, 1);
    expect(find.text('map_fallback_location'.tr()), findsNothing);
    expect(find.textContaining('40.0000'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
