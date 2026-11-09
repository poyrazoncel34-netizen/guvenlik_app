// Tile server refusal (403/429), stalls (timeout) and outages: the map must
// degrade to an explicit "can't load right now" state, never crash, never
// cache the failure, and -- after a refusal -- stop hitting the server.
//
// OSMF Tile Usage Policy: access "may be blocked without notice"; commercial
// apps "should be especially aware". These tests drive the HTTP boundary with
// a mocked upstream; the widget half lives in
// test/screens/map_tile_outage_widget_test.dart.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/network/map_tile_availability.dart';
import 'package:guvenlik_app/core/network/osm_tile_cache_client.dart';
import 'package:guvenlik_app/core/network/tile_upstream_guard.dart';
import 'package:http/http.dart' as http;

const String kTileUrl = 'https://tile.openstreetmap.org/7/66/45.png';
const String kOtherTileUrl = 'https://tile.openstreetmap.org/7/66/46.png';
const String kPaidTileUrl =
    'https://api.maptiler.com/maps/streets-v2/256/7/66/45.png?key=k';

typedef _Handler =
    Future<http.StreamedResponse> Function(http.BaseRequest request, int index);

class _MockUpstream extends http.BaseClient {
  _MockUpstream(this._handler);

  final _Handler _handler;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final index = requests.length;
    requests.add(request);
    return _handler(request, index);
  }
}

http.StreamedResponse _status(
  http.BaseRequest request,
  int code, {
  Map<String, String> headers = const <String, String>{},
  List<int> body = const <int>[1, 2, 3],
}) => http.StreamedResponse(
  Stream<List<int>>.value(body),
  code,
  request: request,
  headers: <String, String>{'content-type': 'image/png', ...headers},
);

void main() {
  late Directory cacheDirectory;
  late DateTime now;
  late MapTileAvailability availability;

  setUp(() async {
    cacheDirectory = await Directory.systemTemp.createTemp('korubeni-outage-');
    now = DateTime.utc(2026, 11, 9, 12);
    availability = MapTileAvailability();
  });

  tearDown(() async {
    availability.dispose();
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  });

  OsmTileCacheClient makeClient(
    http.BaseClient upstream, {
    Duration timeout = const Duration(milliseconds: 50),
  }) => OsmTileCacheClient(
    cacheDirectory: Future<Directory>.value(cacheDirectory),
    innerClient: upstream,
    now: () => now,
    availability: availability,
    requestTimeout: timeout,
  );

  Future<int> cachedFiles() async =>
      (await cacheDirectory
              .list(recursive: true)
              .where((e) => e is File)
              .toList())
          .length;

  Future<http.StreamedResponse> get(OsmTileCacheClient client, String url) =>
      client.send(http.Request('GET', Uri.parse(url)));

  for (final code in <int>[403, 429]) {
    test(
      '$code: surfaces, is not cached, and reports a blocked outage',
      () async {
        final upstream = _MockUpstream((r, _) async => _status(r, code));
        final client = makeClient(upstream);
        addTearDown(client.close);

        final response = await get(client, kTileUrl);
        await response.stream.drain<void>();

        expect(response.statusCode, code);
        expect(await cachedFiles(), 0);
        expect(availability.value, MapTileOutage.blocked);
        expect(client.upstreamSuspendedUntil, isNotNull);
      },
    );

    test(
      '$code: suspends ALL upstream traffic until the backoff expires',
      () async {
        final upstream = _MockUpstream(
          (r, i) async => i == 0 ? _status(r, code) : _status(r, 200),
        );
        final client = makeClient(upstream);
        addTearDown(client.close);

        await (await get(client, kTileUrl)).stream.drain<void>();

        // A different tile, during the backoff: no request may leave.
        await expectLater(
          get(client, kOtherTileUrl),
          throwsA(
            isA<http.ClientException>().having(
              (e) => e.message,
              'message',
              OsmTileCacheClient.backoffMessage,
            ),
          ),
        );
        expect(upstream.requests, hasLength(1));
        expect(client.upstreamTileRequests, 1);

        // After the window the next tile goes out, succeeds, and clears the
        // outage state.
        now = client.upstreamSuspendedUntil!.add(const Duration(seconds: 1));
        final recovered = await get(client, kOtherTileUrl);
        await recovered.stream.drain<void>();
        expect(recovered.statusCode, 200);
        expect(upstream.requests, hasLength(2));
        expect(availability.value, isNull);
      },
    );
  }

  test('429 honours Retry-After seconds', () async {
    final upstream = _MockUpstream(
      (r, _) async => _status(r, 429, headers: {'retry-after': '120'}),
    );
    final client = makeClient(upstream);
    addTearDown(client.close);

    await (await get(client, kTileUrl)).stream.drain<void>();

    expect(
      client.upstreamSuspendedUntil,
      now.add(const Duration(seconds: 120)),
    );
  });

  test('Retry-After is bounded both ways and accepts HTTP-dates', () {
    expect(
      TileUpstreamBackoff.durationFor(429, '0', now),
      TileUpstreamBackoff.minimum,
      reason: 'Retry-After: 0 must not turn into hammering',
    );
    expect(
      TileUpstreamBackoff.durationFor(429, '999999', now),
      TileUpstreamBackoff.maximum,
      reason: 'a broken header must not disable the map for days',
    );
    expect(
      TileUpstreamBackoff.durationFor(
        429,
        HttpDate.format(now.add(const Duration(minutes: 10))),
        now,
      ),
      const Duration(minutes: 10),
    );
    expect(
      TileUpstreamBackoff.durationFor(429, 'garbage', now),
      TileUpstreamBackoff.rateLimitedDefault,
    );
    expect(
      TileUpstreamBackoff.durationFor(403, null, now),
      TileUpstreamBackoff.refusedDefault,
    );
  });

  test(
    'during a backoff an expired cached tile is served instead of blank',
    () async {
      final upstream = _MockUpstream((r, i) async {
        if (i == 0) {
          return _status(
            r,
            200,
            body: <int>[9, 9],
            headers: {'cache-control': 'max-age=60'},
          );
        }
        return _status(r, 429);
      });
      final client = makeClient(upstream);
      addTearDown(client.close);

      await (await get(client, kTileUrl)).stream.drain<void>();
      now = now.add(const Duration(minutes: 5)); // cached copy now expired
      await (await get(client, kOtherTileUrl)).stream.drain<void>(); // 429

      final stale = await get(client, kTileUrl);
      expect(stale.statusCode, 200);
      expect(await stale.stream.toBytes(), <int>[9, 9]);
      expect(
        upstream.requests,
        hasLength(2),
        reason: 'no request while blocked',
      );
    },
  );

  test('timeout: a stalled server yields a bounded ClientException', () async {
    final upstream = _MockUpstream(
      (r, _) => Completer<http.StreamedResponse>().future,
    );
    final client = makeClient(upstream);
    addTearDown(client.close);

    final watch = Stopwatch()..start();
    await expectLater(
      get(client, kTileUrl),
      throwsA(
        isA<http.ClientException>().having(
          (e) => e.message,
          'message',
          OsmTileCacheClient.timeoutMessage,
        ),
      ),
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    expect(await cachedFiles(), 0);
  });

  test(
    'timeout: a stalled body is bounded AND its connection released',
    () async {
      var cancelled = false;
      final upstream = _MockUpstream((r, _) async {
        final controller = StreamController<List<int>>(
          onCancel: () => cancelled = true,
        );
        controller.add(<int>[1]); // never closed
        return http.StreamedResponse(
          controller.stream,
          200,
          request: r,
          headers: const {'content-type': 'image/png'},
        );
      });
      final client = makeClient(upstream);
      addTearDown(client.close);

      await expectLater(
        get(client, kTileUrl),
        throwsA(isA<http.ClientException>()),
      );
      expect(await cachedFiles(), 0);
      expect(
        cancelled,
        isTrue,
        reason: 'a timed-out read that keeps its subscription keeps the socket',
      );
    },
  );

  test('a mid-body connection reset counts as a network failure', () async {
    final upstream = _MockUpstream((r, _) async {
      final controller = StreamController<List<int>>();
      controller.addError(http.ClientException('Connection reset by peer'));
      unawaited(controller.close());
      return http.StreamedResponse(
        controller.stream,
        200,
        request: r,
        headers: const {'content-type': 'image/png'},
      );
    });
    final client = makeClient(upstream);
    addTearDown(client.close);

    for (var i = 0; i < MapTileAvailability.networkFailureThreshold; i++) {
      await expectLater(
        get(client, 'https://tile.openstreetmap.org/7/66/$i.png'),
        throwsA(isA<http.ClientException>()),
      );
    }
    expect(availability.value, MapTileOutage.network);
  });

  test('an oversized tile is a bad tile, not a network outage', () async {
    final upstream = _MockUpstream(
      (r, _) async => _status(r, 200, body: List<int>.filled(64, 7)),
    );
    final client = OsmTileCacheClient(
      cacheDirectory: Future<Directory>.value(cacheDirectory),
      innerClient: upstream,
      now: () => now,
      availability: availability,
      cacheByteLimit: 32,
      tileByteLimit: 32,
    );
    addTearDown(client.close);

    for (var i = 0; i < MapTileAvailability.networkFailureThreshold; i++) {
      await expectLater(
        get(client, 'https://tile.openstreetmap.org/7/66/$i.png'),
        throwsA(isA<http.ClientException>()),
      );
    }
    expect(availability.value, isNull);
  });

  test('5xx answers in a row become a network outage', () async {
    final upstream = _MockUpstream((r, _) async => _status(r, 502));
    final client = makeClient(upstream);
    addTearDown(client.close);

    for (var i = 0; i < MapTileAvailability.networkFailureThreshold; i++) {
      await (await get(
        client,
        'https://tile.openstreetmap.org/7/66/$i.png',
      )).stream.drain<void>();
    }
    expect(availability.value, MapTileOutage.network);
    expect(client.upstreamSuspendedUntil, isNull);
  });

  test('a success already in flight does not clear an active block', () async {
    final slowSuccess = Completer<http.StreamedResponse>();
    final upstream = _MockUpstream((r, i) {
      if (i == 0) return slowSuccess.future;
      return Future.value(_status(r, 429));
    });
    final client = makeClient(upstream, timeout: const Duration(seconds: 5));
    addTearDown(client.close);

    final inFlight = get(client, kTileUrl);
    await (await get(client, kOtherTileUrl)).stream.drain<void>(); // 429
    expect(availability.value, MapTileOutage.blocked);

    slowSuccess.complete(_status(upstream.requests.first, 200));
    await (await inFlight).stream.drain<void>();
    expect(
      availability.value,
      MapTileOutage.blocked,
      reason: 'traffic is still suspended; the banner must not flicker off',
    );
  });

  test('Retry-After is anchored to when the answer arrived', () async {
    final upstream = _MockUpstream((r, _) async {
      now = now.add(const Duration(seconds: 10)); // slow round trip
      return _status(r, 429, headers: {'retry-after': '120'});
    });
    final client = makeClient(upstream, timeout: const Duration(seconds: 5));
    final sentAt = now;
    addTearDown(client.close);

    await (await get(client, kTileUrl)).stream.drain<void>();

    expect(
      client.upstreamSuspendedUntil,
      sentAt.add(const Duration(seconds: 130)),
    );
  });

  test(
    'a refusal that arrives after the timeout still suspends traffic',
    () async {
      final lateAnswer = Completer<http.StreamedResponse>();
      final upstream = _MockUpstream((r, i) {
        if (i == 0) return lateAnswer.future;
        return Future.value(_status(r, 200));
      });
      final client = makeClient(upstream);
      addTearDown(client.close);

      await expectLater(
        get(client, kTileUrl),
        throwsA(isA<http.ClientException>()),
      );
      lateAnswer.complete(_status(upstream.requests.first, 429));
      await pumpEventQueue();

      expect(client.upstreamSuspendedUntil, isNotNull);
      expect(availability.value, MapTileOutage.blocked);
      await expectLater(
        get(client, kOtherTileUrl),
        throwsA(isA<http.ClientException>()),
      );
      expect(upstream.requests, hasLength(1));
    },
  );

  test('a huge Retry-After cannot overflow below the maximum', () {
    expect(
      TileUpstreamBackoff.durationFor(429, '9223372036854775', now),
      TileUpstreamBackoff.maximum,
    );
  });

  test(
    'moving the wall clock back cannot stretch a block past the maximum',
    () {
      final backoff = TileUpstreamBackoff()..open(429, '3600', now);
      expect(backoff.isOpen(now), isTrue);
      expect(
        backoff.isOpen(now.subtract(const Duration(days: 1))),
        isFalse,
        reason: 'a block 25 h ahead can only be clock skew',
      );
    },
  );

  for (final failure in <String>['429', '503', 'timeout']) {
    test('revalidation $failure serves the expired copy in hand', () async {
      final upstream = _MockUpstream((r, i) {
        if (i == 0) {
          return Future.value(
            _status(
              r,
              200,
              body: <int>[4, 2],
              headers: {'cache-control': 'max-age=60', 'etag': '"v1"'},
            ),
          );
        }
        return switch (failure) {
          '429' => Future.value(_status(r, 429)),
          '503' => Future.value(_status(r, 503)),
          _ => Completer<http.StreamedResponse>().future,
        };
      });
      final client = makeClient(upstream);
      addTearDown(client.close);

      await (await get(client, kTileUrl)).stream.drain<void>();
      now = now.add(const Duration(minutes: 5));

      final response = await get(client, kTileUrl);
      expect(response.statusCode, 200);
      expect(await response.stream.toBytes(), <int>[4, 2]);
      expect(upstream.requests, hasLength(2));
    });
  }

  test(
    'repeated timeouts become a network outage; one success clears it',
    () async {
      var stall = true;
      final upstream = _MockUpstream((r, _) async {
        if (stall) return Completer<http.StreamedResponse>().future;
        return _status(r, 200);
      });
      final client = makeClient(upstream);
      addTearDown(client.close);

      for (
        var i = 0;
        i < MapTileAvailability.networkFailureThreshold - 1;
        i++
      ) {
        await expectLater(
          get(client, 'https://tile.openstreetmap.org/7/66/$i.png'),
          throwsA(isA<http.ClientException>()),
        );
      }
      expect(
        availability.value,
        isNull,
        reason: 'a couple of slow tiles is not an outage',
      );

      await expectLater(
        get(client, 'https://tile.openstreetmap.org/7/66/40.png'),
        throwsA(isA<http.ClientException>()),
      );
      expect(availability.value, MapTileOutage.network);
      expect(
        client.upstreamSuspendedUntil,
        isNull,
        reason: 'timeouts are not a refusal and must not suspend traffic',
      );

      stall = false;
      await (await get(client, kTileUrl)).stream.drain<void>();
      expect(availability.value, isNull);
    },
  );

  test('socket errors count as network failures and do not crash', () async {
    final upstream = _MockUpstream(
      (r, _) async => throw const SocketException('unreachable'),
    );
    final client = makeClient(upstream);
    addTearDown(client.close);

    for (var i = 0; i < MapTileAvailability.networkFailureThreshold; i++) {
      await expectLater(
        get(client, 'https://tile.openstreetmap.org/7/66/$i.png'),
        throwsA(isA<SocketException>()),
      );
    }
    expect(availability.value, MapTileOutage.network);
  });

  test(
    'a configured paid provider gets the same backoff and timeout',
    () async {
      final upstream = _MockUpstream((r, _) async => _status(r, 429));
      final client = makeClient(upstream);
      addTearDown(client.close);

      final first = await get(client, kPaidTileUrl);
      await first.stream.drain<void>();
      expect(first.statusCode, 429);
      expect(availability.value, MapTileOutage.blocked);
      await expectLater(
        get(client, kPaidTileUrl),
        throwsA(isA<http.ClientException>()),
      );
      expect(upstream.requests, hasLength(1));
    },
  );

  test('a paid provider body stall is bounded by the timeout', () async {
    final upstream = _MockUpstream((r, _) async {
      final controller = StreamController<List<int>>();
      return http.StreamedResponse(controller.stream, 200, request: r);
    });
    final client = makeClient(upstream);
    addTearDown(client.close);

    final response = await get(client, kPaidTileUrl);
    await expectLater(
      response.stream.toBytes(),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('reports after the map page disposed the notifier are dropped', () {
    final notifier = MapTileAvailability()..dispose();
    expect(notifier.reportBlocked, returnsNormally);
    expect(notifier.reportNetworkFailure, returnsNormally);
    expect(notifier.reportSuccess, returnsNormally);
  });

  test('a timeout after a refusal keeps the more specific blocked label', () {
    availability.reportBlocked();
    for (var i = 0; i < MapTileAvailability.networkFailureThreshold; i++) {
      availability.reportNetworkFailure();
    }
    expect(availability.value, MapTileOutage.blocked);
  });
}
