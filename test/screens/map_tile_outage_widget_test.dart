// Widget evidence for the map's tile-outage state and attribution visibility.
//
// The real chain runs: flutter_map TileLayer -> NetworkTileProvider ->
// OsmTileCacheClient -> a MOCKED upstream http client. Nothing touches the
// network or the disk (the cache directory future fails, which the client
// already treats as "no cache").
//
// OSMF attribution guideline: visible without user interaction and never
// hidden beneath other UI. "Visible" is checked by hit-testing the credit
// line's centre -- if any overlay painted above it, the hit would land there.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guvenlik_app/core/config/app_environment.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/network/map_tile_availability.dart';
import 'package:guvenlik_app/core/network/osm_tile_cache_client.dart';
import 'package:guvenlik_app/core/services/connectivity_service.dart';
import 'package:guvenlik_app/core/services/location_service.dart';
import 'package:guvenlik_app/core/utils/map_utils.dart';
import 'package:guvenlik_app/data/repositories/location_repository_impl.dart';
import 'package:guvenlik_app/domain/repositories/location_repository.dart';
import 'package:guvenlik_app/screens/map_page.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:guvenlik_app/widgets/map_tile_overlays.dart';
import 'package:http/http.dart' as http;
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
  bool hang = false;
  bool fail = false;

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    if (hang) return Completer<Position>().future;
    if (fail) return Future<Position>.error(TimeoutException('no fix'));
    return Future<Position>.value(
      Position(
        latitude: 41.01,
        longitude: 28.97,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
  }
}

class _MockUpstream extends http.BaseClient {
  _MockUpstream(this._respond);

  final Future<http.StreamedResponse> Function(http.BaseRequest) _respond;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return _respond(request);
  }
}

_MockUpstream _statusUpstream(int code) => _MockUpstream(
  (r) async => http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode('refused')),
    code,
    request: r,
    headers: const {'content-type': 'text/plain'},
  ),
);

final List<int> _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _LocationPlatform platform;
  late MapTileAvailability availability;

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
    availability = MapTileAvailability();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
    imageCache.clear();
  });

  tearDown(() async {
    availability.dispose();
    await serviceLocator.reset();
  });

  OsmTileCacheClient tileClient(http.BaseClient upstream) {
    // A cache directory that cannot be opened: the client must fall through
    // to the network. ignore() marks the error handled for this test zone.
    final noCache = Future<Directory>.error(
      const FileSystemException('test: no tile cache'),
    )..ignore();
    return OsmTileCacheClient(
      cacheDirectory: noCache,
      innerClient: upstream,
      availability: availability,
    );
  }

  Future<void> mount(
    WidgetTester tester,
    http.BaseClient upstream, {
    double scale = 1,
  }) async {
    await ConnectivityService.instance.initialize();
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
              child: MapPage(
                tileHttpClient: tileClient(upstream),
                tileAvailability: availability,
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  void expectAttributionVisibleOnTop(WidgetTester tester) {
    final credit = find.text(AppEnvironment.mapTileAttribution);
    expect(credit, findsOneWidget);
    final rect = tester.getRect(credit);
    const screen = Rect.fromLTWH(0, 0, 360, 640);
    expect(
      screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
      isTrue,
      reason: 'attribution must be fully on screen, got $rect',
    );
    final hit = tester.hitTestOnBinding(rect.center);
    expect(
      hit.path.any((entry) => entry.target == tester.renderObject(credit)),
      isTrue,
      reason: 'another overlay is painted above the attribution',
    );
  }

  // A getter, not a top-level value: .tr() before EasyLocalization has
  // loaded returns the raw key and every finder would silently miss.
  String bannerTitle() => 'map_tiles_unavailable'.tr();

  testWidgets('tiles loading normally: no banner, attribution on top, app UA', (
    tester,
  ) async {
    final upstream = _MockUpstream(
      (r) async => http.StreamedResponse(
        Stream<List<int>>.value(_onePixelPng),
        200,
        request: r,
        headers: const {'content-type': 'image/png'},
      ),
    );
    await mount(tester, upstream);

    expect(upstream.requests, isNotEmpty, reason: 'tile layer never fetched');
    expect(upstream.requests.first.headers['User-Agent'], kMapTileUserAgent);
    expect(availability.value, isNull);
    expect(find.text(bannerTitle()), findsNothing);
    expectAttributionVisibleOnTop(tester);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  for (final code in <int>[403, 429]) {
    testWidgets(
      '$code from the tile server: explains, keeps attribution, no crash',
      (tester) async {
        final upstream = _statusUpstream(code);
        await mount(tester, upstream);

        expect(upstream.requests, isNotEmpty);
        expect(availability.value, MapTileOutage.blocked);
        expect(find.text(bannerTitle()), findsOneWidget);
        expect(find.text('map_tiles_unavailable_blocked'.tr()), findsOneWidget);
        // A live region must carry its text, or TalkBack announces nothing.
        final semantics = tester.ensureSemantics();
        await tester.pump();
        expect(
          find.bySemanticsLabel(
            RegExp(
              '${RegExp.escape(bannerTitle())}.*'
              '${RegExp.escape('map_tiles_unavailable_blocked'.tr())}',
              dotAll: true,
            ),
          ),
          findsOneWidget,
        );
        semantics.dispose();
        expectAttributionVisibleOnTop(tester);
        expect(tester.takeException(), isNull);

        // Panning after the refusal must not reach the server again.
        final before = upstream.requests.length;
        await tester.drag(find.byType(MapPage), const Offset(-300, 0));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(upstream.requests.length, before);
        await unmount(tester);
      },
    );
  }

  testWidgets('stalled tile server: times out into the network banner', (
    tester,
  ) async {
    final upstream = _MockUpstream(
      (_) => Completer<http.StreamedResponse>().future,
    );
    await mount(tester, upstream);
    expect(
      find.text(bannerTitle()),
      findsNothing,
      reason: 'too early to give up',
    );

    await tester.pump(
      OsmTileCacheClient.defaultRequestTimeout + const Duration(seconds: 1),
    );
    await tester.pump();

    expect(availability.value, MapTileOutage.network);
    expect(find.text(bannerTitle()), findsOneWidget);
    expect(find.text('map_tiles_unavailable_network'.tr()), findsOneWidget);
    expectAttributionVisibleOnTop(tester);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('attribution stays above the loading overlay', (tester) async {
    platform.hang = true;
    await mount(tester, _statusUpstream(429));

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expectAttributionVisibleOnTop(tester);
    expect(find.text(bannerTitle()), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Let LocationService's own fix timeout fire so no timer outlives the test.
    await tester.pump(const Duration(minutes: 2));
    await unmount(tester);
  });

  // The bottom overlays used to be three independent layers (bottom 220 /
  // 130 / 24). With large text the controls card grew over the attribution.
  // Now they form one stack: nothing may overlap at any scale, and at the
  // default scale every edge must sit exactly where it used to.
  for (final scale in <double>[1.0, 1.3, 2.0]) {
    testWidgets('bottom overlays never overlap at text scale $scale', (
      tester,
    ) async {
      platform.fail = true; // -> fallback-location banner as well
      await mount(tester, _statusUpstream(429), scale: scale);
      await tester.pump(const Duration(seconds: 11));

      final stack = tester.widget<MapBottomStack>(find.byType(MapBottomStack));
      final credit = tester.getRect(find.byType(MapTileAttribution));
      final outage = tester.getRect(find.byType(MapTilesUnavailableBanner));
      final fallback = tester.getRect(find.byType(MapFallbackLocationBanner));
      final controls = tester.getRect(find.byWidget(stack.controls));
      final rects = <String, Rect>{
        'credit': credit,
        'outage': outage,
        'fallback': fallback,
        'controls': controls,
      };
      final names = rects.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          expect(
            rects[names[i]]!.overlaps(rects[names[j]]!),
            isFalse,
            reason:
                '${names[i]} ${rects[names[i]]} overlaps '
                '${names[j]} ${rects[names[j]]}',
          );
        }
      }
      expectAttributionVisibleOnTop(tester);

      if (scale == 1.0) {
        // Old geometry: credit at left 12 / bottom 130, banners ending at
        // bottom 220, controls at 16..344 / bottom 24.
        expect(credit.left, 12);
        expect(640 - credit.bottom, 130);
        expect(640 - fallback.bottom, 220);
        expect(fallback.left, 16);
        expect(fallback.right, 344);
        expect(controls.left, 16);
        expect(controls.right, 344);
        expect(640 - controls.bottom, 24);
      }
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }

  // Offline (no TileLayer at all, offline surface instead) is covered by
  // map_freshness_widget_test.dart; ConnectivityService is a process-wide
  // singleton, so this file cannot flip it after the first initialize().
}
