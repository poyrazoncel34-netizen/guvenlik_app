// MP-19-001..011 / MP-19-025 / MP-19-026 — HTTP failure handling.
//
// This app has no backend. Its ONLY own HTTP traffic is OSM raster tiles, an
// optional map layer that the emergency path never touches. The audit
// previously marked every status-code row PARTIAL because the codes are
// "handled as one generic failure class rather than individually".
//
// For tile fetching, uniform handling is the CORRECT design, not a shortfall:
// there is no per-status UI a map tile could show, and the only decisions that
// matter are (a) do not render a broken tile, (b) do not cache a failure, and
// (c) keep serving a still-fresh cached tile. What was missing was evidence
// that each code actually takes that path — so each code is driven here
// individually rather than assumed to fall into the same branch.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/network/osm_tile_cache_client.dart';
import 'package:http/http.dart' as http;

const String kTileUrl = 'https://tile.openstreetmap.org/7/66/45.png';
final List<int> kTileBody = utf8.encode('PNGDATA-OK');

class _StatusClient extends http.BaseClient {
  _StatusClient(this.statusCode, {this.body = const <int>[]});
  final int statusCode;
  final List<int> body;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([body]),
      statusCode,
      request: request,
      headers: const {'content-type': 'image/png'},
    );
  }
}

void main() {
  late Directory cacheDirectory;
  late DateTime now;

  setUp(() async {
    cacheDirectory = await Directory.systemTemp.createTemp('korubeni-tile-status-');
    now = DateTime.utc(2026, 7, 19, 12);
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

  /// RECURSIVE on purpose. A top-level-only count returns 0 for every case,
  /// which would make every "never cached" assertion below pass without
  /// measuring anything. The positive-control test at the end is what proves
  /// this counter can be non-zero at all.
  Future<int> cachedFileCount() async {
    if (!await cacheDirectory.exists()) return 0;
    return cacheDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .length;
  }

  // Every status code the checklist names, plus the two write-semantics codes
  // that a GET-only client can still be handed by a misbehaving proxy.
  const codes = <int, String>{
    400: 'MP-19-001 Bad Request',
    401: 'MP-19-002 Unauthorized',
    403: 'MP-19-003 Forbidden',
    404: 'MP-19-004 Not Found',
    409: 'MP-19-005 Conflict',
    422: 'MP-19-006 Unprocessable',
    500: 'MP-19-008 Internal Server Error',
    502: 'MP-19-009 Bad Gateway',
    503: 'MP-19-010 Service Unavailable',
    504: 'MP-19-011 Gateway Timeout',
  };

  codes.forEach((code, label) {
    test('$label: surfaces without throwing and is never cached', () async {
      final upstream = _StatusClient(code, body: utf8.encode('error page'));
      final client = makeClient(upstream);
      addTearDown(client.close);

      final response = await client.send(
        http.Request('GET', Uri.parse(kTileUrl)),
      );
      await response.stream.drain<void>();

      // Precondition: the request really reached upstream, so a "no crash"
      // result cannot come from the request being skipped entirely.
      expect(upstream.calls, 1, reason: 'upstream was not called for $code');

      expect(
        response.statusCode,
        code,
        reason: 'the status must be surfaced to flutter_map, not swallowed',
      );
      expect(
        await cachedFileCount(),
        0,
        reason:
            'caching a $code would serve the error page as a tile for up to '
            'seven days',
      );
    });
  });

  test('a still-fresh cached tile survives an upstream outage', () async {
    // Populate the cache from a good response.
    final good = _StatusClient(200, body: kTileBody);
    final warm = makeClient(good);
    final first = await warm.send(http.Request('GET', Uri.parse(kTileUrl)));
    await first.stream.drain<void>();
    warm.close();

    // Precondition: the cache really was populated, otherwise the assertion
    // below would pass against an empty cache doing nothing.
    expect(
      await cachedFileCount(),
      greaterThan(0),
      reason: 'harness precondition: the tile must have been cached',
    );

    // Now the server is down. The cached tile is still inside its lifetime.
    final down = _StatusClient(503);
    final client = makeClient(down);
    addTearDown(client.close);
    final response = await client.send(
      http.Request('GET', Uri.parse(kTileUrl)),
    );
    final bytes = await response.stream.toBytes();

    expect(response.statusCode, 200);
    expect(
      bytes,
      kTileBody,
      reason:
          'the map must keep showing what it already has during an outage; '
          'this is the difference between a degraded map and a blank one',
    );
    expect(
      down.calls,
      0,
      reason: 'a fresh cache entry must not even ask the failing server',
    );
  });

  group('MP-19-025 / MP-19-026: retry backoff', () {
    test('delay grows exponentially and is capped', () {
      // Deterministic: full jitter forced to its maximum.
      double maxJitter() => 1.0;
      final delays = <int>[
        for (var retry = 0; retry < 6; retry++)
          OsmTileCacheClient.retryDelayFor(
            retry,
            randomSource: maxJitter,
          ).inMilliseconds,
      ];
      expect(delays[0], 500);
      expect(delays[1], 1000);
      expect(delays[2], 2000);
      expect(delays[3], 4000);
      // Capped, not unbounded.
      expect(delays[4], OsmTileCacheClient.retryMaxDelay.inMilliseconds);
      expect(delays[5], OsmTileCacheClient.retryMaxDelay.inMilliseconds);
      for (var i = 1; i < 4; i++) {
        expect(
          delays[i],
          greaterThan(delays[i - 1]),
          reason: 'backoff must actually back off',
        );
      }
    });

    test('jitter spreads simultaneous retries instead of aligning them', () {
      // Two devices that failed at the same instant must not retry together.
      double lowest() => 0.0;
      double highest() => 1.0;
      final earliest =
          OsmTileCacheClient.retryDelayFor(2, randomSource: lowest);
      final latest =
          OsmTileCacheClient.retryDelayFor(2, randomSource: highest);

      expect(
        earliest,
        lessThan(latest),
        reason:
            'without jitter these are equal, which is the thundering herd '
            'against OSM this project is a guest on',
      );
      // Full jitter spans 50%-100% of the capped delay.
      expect(earliest.inMilliseconds, 1000);
      expect(latest.inMilliseconds, 2000);
    });

    test('the production client is built with that policy, not the default',
        () {
      final source = File(
        'lib/core/network/osm_tile_cache_client.dart',
      ).readAsStringSync();
      expect(
        source,
        contains('innerClient ?? buildRetryClient()'),
        reason: 'the default RetryClient() has no jitter',
      );
      expect(
        source,
        contains('delay: retryDelayFor'),
        reason: 'the jittered delay must actually be wired into RetryClient',
      );
      expect(source, contains('retries: retryCount'));
    });
  });
}
