// MP-42-024 -- dependency quotas: how many tile requests does a real session
// send to OSM?
//
// The row was open because the cache CONTRACT was documented and the request
// VOLUME was not, so nothing could be compared against OpenStreetMap's
// bulk-use policy -- a policy this project is a guest under, not a customer of.
//
// The number here is computed, not chosen: the tile count per viewport comes
// from the shipped map configuration and a real device's screen metrics, and
// the upstream count comes from driving the actual client with that traffic.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/network/osm_tile_cache_client.dart';
import 'package:http/http.dart' as http;

/// Shipped map configuration, read from `map_page.dart` so a change to the map
/// invalidates this measurement instead of silently outdating it.
class _MapConfig {
  _MapConfig(String source)
    : minZoom = _num(source, r'minZoom:\s*([0-9.]+)'),
      maxZoom = _num(source, r'maxZoom:\s*([0-9.]+)');

  final double minZoom;
  final double maxZoom;

  static double _num(String source, String pattern) {
    final match = RegExp(pattern).firstMatch(source);
    if (match == null) throw StateError('map config changed: $pattern');
    return double.parse(match.group(1)!);
  }
}

/// Emulator Medium_Phone_API_36.1, measured: 1080x2400 px at DPR 2.75.
const double _logicalWidth = 1080 / 2.75;
const double _logicalHeight = 2400 / 2.75;

/// flutter_map's tile side, and the ring of off-screen tiles it keeps ready.
const int _tileSide = 256;
const int _keepBuffer = 1;

int _tilesPerViewport() {
  final across = (_logicalWidth / _tileSide).ceil() + 1 + 2 * _keepBuffer;
  final down = (_logicalHeight / _tileSide).ceil() + 1 + 2 * _keepBuffer;
  return across * down;
}

void main() {
  late Directory cacheDirectory;
  late DateTime now;

  setUp(() async {
    cacheDirectory =
        await Directory.systemTemp.createTemp('korubeni-tile-volume-');
    now = DateTime.utc(2026, 8, 15, 12);
  });

  tearDown(() async {
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  });

  OsmTileCacheClient makeClient(http.BaseClient upstream) => OsmTileCacheClient(
    cacheDirectory: Future<Directory>.value(cacheDirectory),
    innerClient: upstream,
    now: () => now,
  );

  Uri tile(int z, int x, int y) =>
      Uri.parse('https://tile.openstreetmap.org/$z/$x/$y.png');

  Future<void> request(OsmTileCacheClient client, Uri uri) async {
    final response = await client.send(
      http.Request('GET', uri)..headers['User-Agent'] = 'KoruBeni/test',
    );
    await response.stream.drain<void>();
  }

  test('the viewport tile count is derived from the shipped map config', () {
    final config = _MapConfig(
      File('lib/screens/map_page.dart').readAsStringSync(),
    );
    expect(config.minZoom, 3.0);
    expect(config.maxZoom, 18.0);
    // 393x873 logical / 256 -> 2x4 visible, +1 partial each axis, +1 buffer ring
    expect(_tilesPerViewport(), 5 * 7);
  });

  test('MEASURED: a representative session and what it costs OSM', () async {
    // A representative session for THIS app: the user opens the map once during
    // a safety session, looks at where they are, zooms in twice to street level
    // and pans one screen. That is four viewports.
    const viewports = 4;
    final perViewport = _tilesPerViewport();

    var upstreamCalls = 0;
    final upstream = _RecordingClient((req, _) {
      upstreamCalls++;
      return http.StreamedResponse(
        Stream<List<int>>.value(<int>[1, 2, 3]),
        200,
        contentLength: 3,
        headers: <String, String>{
          'content-type': 'image/png',
          'cache-control': 'public, max-age=86400',
        },
        request: req,
      );
    });
    final client = makeClient(upstream);
    addTearDown(client.close);
    client.resetTileCounters();

    // Viewport 1: zoom 15. Viewports 2-3: zoom in, each sharing a quarter of
    // the previous view's area. Viewport 4: pan by one screen at zoom 17.
    var requested = 0;
    for (var v = 0; v < viewports; v++) {
      final z = 15 + (v < 3 ? v : 2);
      for (var i = 0; i < perViewport; i++) {
        final x = 19000 + (v == 3 ? 5 : 0) + i % 7;
        final y = 12000 + (v == 3 ? 5 : 0) + i ~/ 7;
        await request(client, tile(z, x, y));
        requested++;
      }
    }

    // ignore: avoid_print
    print('MP-42-024 session: viewports=$viewports '
        'tilesPerViewport=$perViewport requested=$requested '
        'upstream=${client.upstreamTileRequests} '
        'servedLocally=${client.tileRequestsServedLocally}');

    expect(client.tileRequests, requested);
    expect(client.upstreamTileRequests, upstreamCalls);
    expect(
      client.upstreamTileRequests + client.tileRequestsServedLocally,
      client.tileRequests,
      reason: 'every request must be accounted for as either upstream or local',
    );

    // The policy figure. OSM's tile usage policy names "heavy use (e.g. > 250
    // tiles/sec)" and bulk downloading as unacceptable; a session that costs
    // under a few hundred tiles, spread across seconds of human panning, is far
    // below that. The assertion is deliberately an ORDER-OF-MAGNITUDE bound,
    // not a golden number: pinning the exact count would break on any map
    // layout change without telling anyone anything about the quota.
    expect(client.upstreamTileRequests, lessThan(250),
        reason: 'one session must not approach the per-SECOND ceiling OSM '
            'names as heavy use');
  });

  test('a second look at the same area costs OSM nothing', () async {
    final upstream = _RecordingClient((req, _) => http.StreamedResponse(
          Stream<List<int>>.value(<int>[1, 2, 3]),
          200,
          contentLength: 3,
          headers: <String, String>{
            'content-type': 'image/png',
            'cache-control': 'public, max-age=86400',
          },
          request: req,
        ));
    final client = makeClient(upstream);
    addTearDown(client.close);

    for (var i = 0; i < 12; i++) {
      await request(client, tile(15, 19000 + i, 12000));
    }
    final firstPass = client.upstreamTileRequests;
    expect(firstPass, 12);

    // The user closes the map and reopens it in the same place.
    client.resetTileCounters();
    for (var i = 0; i < 12; i++) {
      await request(client, tile(15, 19000 + i, 12000));
    }
    expect(client.upstreamTileRequests, 0,
        reason: 'the cache contract exists precisely so a re-open is free');
    expect(client.tileRequestsServedLocally, 12);
  });

  test('concurrent requests for one tile hit OSM once', () async {
    var upstreamCalls = 0;
    final completer = Completer<void>();
    final upstream = _RecordingClient((req, _) async {
      upstreamCalls++;
      await completer.future;
      return http.StreamedResponse(
        Stream<List<int>>.value(<int>[1]),
        200,
        contentLength: 1,
        headers: const <String, String>{'content-type': 'image/png'},
        request: req,
      );
    });
    final client = makeClient(upstream);
    addTearDown(client.close);

    final uri = tile(16, 1, 1);
    final pending = <Future<void>>[
      for (var i = 0; i < 8; i++) request(client, uri),
    ];
    completer.complete();
    await Future.wait(pending);

    expect(upstreamCalls, 1,
        reason: 'eight simultaneous asks for one tile is exactly the pattern a '
            'fast pan produces, and it must not become eight requests');
    expect(client.tileRequests, 8);
    expect(client.upstreamTileRequests, 1);
    expect(client.tileRequestsServedLocally, 7);
  });

  test('the counters start at zero and reset', () async {
    final client = makeClient(_RecordingClient((req, _) =>
        http.StreamedResponse(const Stream<List<int>>.empty(), 200,
            request: req)));
    addTearDown(client.close);
    expect(client.tileRequests, 0);
    expect(client.upstreamTileRequests, 0);
    expect(client.tileRequestsServedLocally, 0);
  });
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._handler);

  final FutureOr<http.StreamedResponse> Function(
    http.BaseRequest request,
    int index,
  )
  _handler;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final index = requests.length;
    requests.add(request);
    return _handler(request, index);
  }
}
