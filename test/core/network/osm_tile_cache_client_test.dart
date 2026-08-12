import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/network/osm_tile_cache_client.dart';
import 'package:http/http.dart' as http;

void main() {
  late Directory cacheDirectory;
  late DateTime now;

  setUp(() async {
    cacheDirectory = await Directory.systemTemp.createTemp(
      'korubeni-osm-cache-test-',
    );
    now = DateTime.utc(2026, 7, 19, 12);
  });

  tearDown(() async {
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  });

  OsmTileCacheClient makeClient(
    http.BaseClient upstream, {
    int cacheByteLimit = OsmTileCacheClient.maxCacheBytes,
    int tileByteLimit = OsmTileCacheClient.maxTileBytes,
  }) => OsmTileCacheClient(
    cacheDirectory: Future<Directory>.value(cacheDirectory),
    innerClient: upstream,
    now: () => now,
    cacheByteLimit: cacheByteLimit,
    tileByteLimit: tileByteLimit,
  );

  test('fresh OSM tile is served from persistent cache', () async {
    final upstream = _RecordingClient((request, _) {
      return _response(
        request,
        200,
        <int>[1, 2, 3],
        headers: <String, String>{
          'content-type': 'image/png',
          'cache-control': 'public, max-age=604800',
          'etag': '"tile-v1"',
        },
      );
    });
    final client = makeClient(upstream);
    final uri = Uri.parse('https://tile.openstreetmap.org/4/9/6.png');

    expect(await client.readBytes(uri), <int>[1, 2, 3]);
    expect(await client.readBytes(uri), <int>[1, 2, 3]);

    expect(upstream.requests, hasLength(1));
    expect(await File('${cacheDirectory.path}/4/9/6.png').readAsBytes(), <int>[
      1,
      2,
      3,
    ]);
    client.close();
  });

  test('expired tile uses ETag revalidation and accepts 304', () async {
    final upstream = _RecordingClient((request, index) {
      if (index == 0) {
        return _response(
          request,
          200,
          <int>[7, 8, 9],
          headers: <String, String>{
            'content-type': 'image/png',
            'cache-control': 'max-age=60',
            'etag': '"tile-v1"',
          },
        );
      }
      expect(request.headers['if-none-match'], '"tile-v1"');
      return _response(
        request,
        304,
        const <int>[],
        headers: <String, String>{'cache-control': 'max-age=120'},
      );
    });
    final client = makeClient(upstream);
    final uri = Uri.parse('https://tile.openstreetmap.org/5/17/12.png');

    expect(await client.readBytes(uri), <int>[7, 8, 9]);
    now = now.add(const Duration(seconds: 61));
    expect(await client.readBytes(uri), <int>[7, 8, 9]);
    expect(await client.readBytes(uri), <int>[7, 8, 9]);

    expect(upstream.requests, hasLength(2));
    client.close();
  });

  test('missing cache headers fall back to a seven-day lifetime', () async {
    final upstream = _RecordingClient(
      (request, _) => _response(
        request,
        200,
        <int>[4, 5, 6],
        headers: <String, String>{'content-type': 'image/png'},
      ),
    );
    final client = makeClient(upstream);
    final uri = Uri.parse('https://tile.openstreetmap.org/3/4/2.png');

    await client.readBytes(uri);
    now = now.add(const Duration(days: 6));
    await client.readBytes(uri);
    expect(upstream.requests, hasLength(1));
    now = now.add(const Duration(days: 2));
    await client.readBytes(uri);
    expect(upstream.requests, hasLength(2));
    client.close();
  });

  test('non-OSM URLs and failed responses are never cached', () async {
    final upstream = _RecordingClient((request, _) {
      final success = request.url.host != 'tile.openstreetmap.org';
      return _response(
        request,
        success ? 200 : 503,
        utf8.encode(success ? 'external' : 'unavailable'),
        headers: <String, String>{'content-type': 'text/plain'},
      );
    });
    final client = makeClient(upstream);
    final external = Uri.parse('https://example.com/4/9/6.png');
    final failedOsm = Uri.parse('https://tile.openstreetmap.org/4/9/6.png');

    await client.readBytes(external);
    await client.readBytes(external);
    await expectLater(
      client.readBytes(failedOsm),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      client.readBytes(failedOsm),
      throwsA(isA<http.ClientException>()),
    );

    expect(upstream.requests, hasLength(4));
    expect(await cacheDirectory.list(recursive: true).toList(), isEmpty);
    client.close();
  });

  test('corrupt cache metadata fails open to a clean network fetch', () async {
    final body = File('${cacheDirectory.path}/2/1/1.png');
    final metadata = File('${cacheDirectory.path}/2/1/1.json');
    await body.parent.create(recursive: true);
    await body.writeAsBytes(<int>[99]);
    await metadata.writeAsString('{broken');
    final upstream = _RecordingClient(
      (request, _) => _response(
        request,
        200,
        <int>[10, 11],
        headers: <String, String>{
          'content-type': 'image/png',
          'cache-control': 'max-age=604800',
        },
      ),
    );
    final client = makeClient(upstream);

    expect(
      await client.readBytes(
        Uri.parse('https://tile.openstreetmap.org/2/1/1.png'),
      ),
      <int>[10, 11],
    );
    expect(upstream.requests, hasLength(1));
    client.close();
  });

  test(
    'concurrent requests for one tile coalesce to one upstream GET',
    () async {
      final release = Completer<void>();
      final started = Completer<void>();
      final upstream = _RecordingClient((request, _) async {
        if (!started.isCompleted) started.complete();
        await release.future;
        return _response(
          request,
          200,
          <int>[12, 13],
          headers: <String, String>{
            'content-type': 'image/png',
            'cache-control': 'max-age=604800',
          },
        );
      });
      final client = makeClient(upstream);
      final uri = Uri.parse('https://tile.openstreetmap.org/6/33/24.png');

      final first = client.readBytes(uri);
      final second = client.readBytes(uri);
      await started.future;
      expect(upstream.requests, hasLength(1));
      release.complete();

      expect(await first, <int>[12, 13]);
      expect(await second, <int>[12, 13]);
      client.close();
    },
  );

  test('no-store and malformed tile coordinates bypass persistence', () async {
    final upstream = _RecordingClient(
      (request, _) => _response(
        request,
        200,
        <int>[14],
        headers: <String, String>{
          'content-type': 'image/png',
          'cache-control': 'no-store',
        },
      ),
    );
    final client = makeClient(upstream);
    final noStore = Uri.parse('https://tile.openstreetmap.org/3/4/2.png');
    final outOfRange = Uri.parse('https://tile.openstreetmap.org/3/999/2.png');
    final withQuery = Uri.parse(
      'https://tile.openstreetmap.org/3/4/2.png?token=unexpected',
    );

    await client.readBytes(noStore);
    await client.readBytes(noStore);
    await client.readBytes(outOfRange);
    await client.readBytes(outOfRange);
    await client.readBytes(withQuery);
    await client.readBytes(withQuery);

    expect(upstream.requests, hasLength(6));
    expect(await cacheDirectory.list(recursive: true).toList(), isEmpty);
    client.close();
  });

  test('oversized tile response is rejected while streaming', () async {
    final upstream = _RecordingClient(
      (request, _) => _response(
        request,
        200,
        <int>[1, 2, 3],
        headers: <String, String>{'content-type': 'image/png'},
      ),
    );
    final client = makeClient(upstream, cacheByteLimit: 4, tileByteLimit: 2);

    await expectLater(
      client.readBytes(Uri.parse('https://tile.openstreetmap.org/1/0/0.png')),
      throwsA(
        isA<http.ClientException>().having(
          (error) => error.message,
          'message',
          'OSM_TILE_RESPONSE_TOO_LARGE',
        ),
      ),
    );
    expect(await cacheDirectory.list(recursive: true).toList(), isEmpty);
    client.close();
  });

  test(
    'expired entries are purged at client startup and never served',
    () async {
      final body = File('${cacheDirectory.path}/1/0/0.png');
      final metadata = File('${cacheDirectory.path}/1/0/0.json');
      await body.parent.create(recursive: true);
      await body.writeAsBytes(<int>[88]);
      await metadata.writeAsString(
        jsonEncode(<String, Object?>{
          'version': OsmTileCacheClient.metadataVersion,
          'expiresAt': now
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
          'etag': '"stale"',
          'lastModified': null,
          'contentType': 'image/png',
          'bodyLength': 1,
        }),
      );
      final upstream = _RecordingClient(
        (request, _) => _response(
          request,
          503,
          utf8.encode('unavailable'),
          headers: <String, String>{'content-type': 'text/plain'},
        ),
      );
      final client = makeClient(upstream);

      await expectLater(
        client.readBytes(Uri.parse('https://tile.openstreetmap.org/1/0/0.png')),
        throwsA(isA<http.ClientException>()),
      );

      expect(await body.exists(), isFalse);
      expect(await metadata.exists(), isFalse);
      expect(upstream.requests.single.headers['if-none-match'], isNull);
      client.close();
    },
  );

  test('startup removes entries whose body does not match metadata', () async {
    final body = File('${cacheDirectory.path}/1/0/0.png');
    final metadata = File('${cacheDirectory.path}/1/0/0.json');
    await body.parent.create(recursive: true);
    await body.writeAsBytes(<int>[1, 2]);
    await metadata.writeAsString(
      jsonEncode(<String, Object?>{
        'version': OsmTileCacheClient.metadataVersion,
        'expiresAt': now.add(const Duration(days: 7)).toIso8601String(),
        'etag': null,
        'lastModified': null,
        'contentType': 'image/png',
        'bodyLength': 99,
      }),
    );
    final upstream = _RecordingClient(
      (request, _) => _response(
        request,
        200,
        <int>[3],
        headers: <String, String>{
          'content-type': 'image/png',
          'cache-control': 'max-age=604800',
        },
      ),
    );
    final client = makeClient(upstream);

    expect(
      await client.readBytes(
        Uri.parse('https://tile.openstreetmap.org/1/0/0.png'),
      ),
      <int>[3],
    );
    expect(upstream.requests, hasLength(1));
    client.close();
  });

  test('startup enforces the persistent cache byte bound', () async {
    Future<void> seedTile(int x, DateTime expiresAt) async {
      final body = File('${cacheDirectory.path}/1/$x/0.png');
      final metadata = File('${cacheDirectory.path}/1/$x/0.json');
      await body.parent.create(recursive: true);
      await body.writeAsBytes(<int>[x, x, x]);
      await metadata.writeAsString(
        jsonEncode(<String, Object?>{
          'version': OsmTileCacheClient.metadataVersion,
          'expiresAt': expiresAt.toIso8601String(),
          'etag': null,
          'lastModified': null,
          'contentType': 'image/png',
          'bodyLength': 3,
        }),
      );
    }

    await seedTile(0, now.add(const Duration(days: 1)));
    await seedTile(1, now.add(const Duration(days: 2)));
    final upstream = _RecordingClient(
      (request, _) => _response(request, 503, const <int>[]),
    );
    final client = makeClient(upstream, cacheByteLimit: 4, tileByteLimit: 4);

    // Any tile request prepares and bounds the existing cache first.
    await expectLater(
      client.readBytes(Uri.parse('https://tile.openstreetmap.org/2/0/0.png')),
      throwsA(isA<http.ClientException>()),
    );

    final bodies = await cacheDirectory
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.png'))
        .cast<File>()
        .toList();
    final retainedBytes = await Future.wait(
      bodies.map((file) => file.length()),
    );
    expect(
      retainedBytes.fold<int>(0, (sum, size) => sum + size),
      lessThanOrEqualTo(4),
    );
    expect(bodies, hasLength(1));
    client.close();
  });

  // OSMF tile policy blocks traffic that carries a library default User-Agent.
  // flutter_map puts the identifying UA on the OUTBOUND request, and this
  // client is the last hop before the socket: if it ever stops forwarding the
  // request it was handed (e.g. by rebuilding a fresh http.Request around the
  // URL), the UA is silently dropped, OSM starts refusing tiles, and the map
  // -- a FREE headline feature -- goes blank in production with every unit
  // test still green. map_utils_osm_user_agent_test.dart pins the UA string
  // itself; this pins that the string actually reaches the wire.
  test('inbound User-Agent reaches upstream on a cold fetch', () async {
    final upstream = _RecordingClient((request, _) {
      return _response(
        request,
        200,
        <int>[1],
        headers: <String, String>{'content-type': 'image/png'},
      );
    });
    final client = makeClient(upstream);
    final request = http.Request(
      'GET',
      Uri.parse('https://tile.openstreetmap.org/4/9/6.png'),
    )..headers['User-Agent'] = 'flutter_map (com.poyrazoncel.korubeni; +x@y.z)';

    await client.send(request);

    expect(
      upstream.requests.single.headers['User-Agent'],
      'flutter_map (com.poyrazoncel.korubeni; +x@y.z)',
      reason: 'the cache client must forward the identifying UA untouched',
    );
    client.close();
  });

  test('inbound User-Agent survives a conditional revalidation', () async {
    final upstream = _RecordingClient((request, index) {
      if (index == 0) {
        return _response(
          request,
          200,
          <int>[1],
          headers: <String, String>{
            'content-type': 'image/png',
            'cache-control': 'public, max-age=1',
            'etag': '"tile-v1"',
          },
        );
      }
      return _response(request, 304, <int>[]);
    });
    final client = makeClient(upstream);
    final uri = Uri.parse('https://tile.openstreetmap.org/4/9/6.png');
    const userAgent = 'flutter_map (com.poyrazoncel.korubeni; +x@y.z)';

    await client.send(
      http.Request('GET', uri)..headers['User-Agent'] = userAgent,
    );
    now = now.add(const Duration(hours: 1));
    // Revalidation adds if-none-match; it must not replace the whole request.
    await client.send(
      http.Request('GET', uri)..headers['User-Agent'] = userAgent,
    );

    expect(upstream.requests, hasLength(2));
    expect(upstream.requests.last.headers['User-Agent'], userAgent);
    expect(upstream.requests.last.headers['if-none-match'], '"tile-v1"');
    client.close();
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

http.StreamedResponse _response(
  http.BaseRequest request,
  int statusCode,
  List<int> body, {
  Map<String, String> headers = const <String, String>{},
}) => http.StreamedResponse(
  Stream<List<int>>.value(body),
  statusCode,
  contentLength: body.length,
  headers: headers,
  request: request,
);
