import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:path_provider/path_provider.dart';

/// Persistent HTTP cache dedicated to OSM's public raster tile endpoint.
///
/// Only exact HTTPS tile URLs are cached. Server cache directives are honored;
/// responses without usable directives receive OSMF's required seven-day
/// fallback lifetime. The cache is app-private, bounded, and never prefetches.
class OsmTileCacheClient extends http.BaseClient {
  OsmTileCacheClient({
    Future<Directory>? cacheDirectory,
    http.BaseClient? innerClient,
    DateTime Function()? now,
    int cacheByteLimit = maxCacheBytes,
    int tileByteLimit = maxTileBytes,
  }) : _cacheDirectory = cacheDirectory ?? _defaultCacheDirectory(),
       _innerClient = innerClient ?? RetryClient(http.Client()),
       _now = now ?? DateTime.now,
       _cacheByteLimit = cacheByteLimit,
       _tileByteLimit = tileByteLimit,
       assert(cacheByteLimit > 0),
       assert(tileByteLimit > 0),
       assert(tileByteLimit <= cacheByteLimit);

  static const Duration fallbackLifetime = Duration(days: 7);
  static const int maxCacheBytes = 128 * 1024 * 1024;
  static const int maxTileBytes = 2 * 1024 * 1024;
  static const int metadataVersion = 1;

  final Future<Directory> _cacheDirectory;
  final http.BaseClient _innerClient;
  final DateTime Function() _now;
  final int _cacheByteLimit;
  final int _tileByteLimit;
  final Map<String, Future<_ResponseSnapshot>> _inFlight =
      <String, Future<_ResponseSnapshot>>{};

  Future<Directory>? _preparedDirectory;
  int _cachedBytes = 0;
  bool _closed = false;

  static Future<Directory> _defaultCacheDirectory() async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}/osm_tiles_v1');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw StateError('OSM tile cache client is closed');

    final address = _TileAddress.tryParse(request);
    if (address == null) return _innerClient.send(request);

    final existing = _inFlight[address.key];
    if (existing != null) {
      return (await existing).toStreamedResponse(request);
    }

    final future = _sendTile(request, address);
    _inFlight[address.key] = future;
    try {
      return (await future).toStreamedResponse(request);
    } finally {
      if (identical(_inFlight[address.key], future)) {
        _inFlight.remove(address.key);
      }
    }
  }

  Future<_ResponseSnapshot> _sendTile(
    http.BaseRequest request,
    _TileAddress address,
  ) async {
    Directory? directory;
    _CacheEntry? cached;
    try {
      directory = await _directory();
      cached = await _readEntry(directory, address);
    } catch (_) {
      // Cache I/O is never allowed to break an optional map request.
    }

    final now = _now().toUtc();
    if (cached != null && now.isBefore(cached.metadata.expiresAt)) {
      return _ResponseSnapshot.cached(cached.body, cached.metadata.contentType);
    }

    if (cached?.metadata.etag case final etag?) {
      request.headers['if-none-match'] = etag;
    }
    if (cached?.metadata.lastModified case final modified?) {
      request.headers['if-modified-since'] = modified;
    }

    final upstream = await _innerClient.send(request);
    final body = await _readBoundedTileBody(upstream.stream);
    final headers = Map<String, String>.from(upstream.headers);

    if (upstream.statusCode == HttpStatus.notModified && cached != null) {
      final policy = _cachePolicy(headers, now);
      if (!policy.store) {
        if (directory != null) await _deleteEntry(directory, address);
      } else if (directory != null) {
        final metadata = cached.metadata.copyWith(
          expiresAt: policy.expiresAt,
          etag: headers['etag'] ?? cached.metadata.etag,
          lastModified:
              headers['last-modified'] ?? cached.metadata.lastModified,
          contentType: headers['content-type'] ?? cached.metadata.contentType,
        );
        await _writeMetadata(directory, address, metadata);
      }
      return _ResponseSnapshot.cached(
        cached.body,
        headers['content-type'] ?? cached.metadata.contentType,
      );
    }

    final snapshot = _ResponseSnapshot.fromUpstream(upstream, body, headers);
    if (directory == null ||
        upstream.statusCode != HttpStatus.ok ||
        body.isEmpty ||
        body.length > _tileByteLimit ||
        !(headers['content-type'] ?? '').toLowerCase().startsWith('image/')) {
      return snapshot;
    }

    final policy = _cachePolicy(headers, now);
    if (!policy.store) {
      await _deleteEntry(directory, address);
      return snapshot;
    }

    final previousLength = cached?.body.length ?? 0;
    if (_cachedBytes - previousLength + body.length > _cacheByteLimit) {
      return snapshot;
    }

    final metadata = _CacheMetadata(
      expiresAt: policy.expiresAt,
      etag: headers['etag'],
      lastModified: headers['last-modified'],
      contentType: headers['content-type'] ?? 'image/png',
      bodyLength: body.length,
    );
    try {
      await _writeEntry(directory, address, body, metadata);
      _cachedBytes = _cachedBytes - previousLength + body.length;
    } catch (_) {
      // Network bytes remain usable even when disk is full or unavailable.
    }
    return snapshot;
  }

  Future<List<int>> _readBoundedTileBody(Stream<List<int>> stream) async {
    final body = <int>[];
    await for (final chunk in stream) {
      if (body.length + chunk.length > _tileByteLimit) {
        throw http.ClientException('OSM_TILE_RESPONSE_TOO_LARGE');
      }
      body.addAll(chunk);
    }
    return body;
  }

  Future<Directory> _directory() => _preparedDirectory ??= _prepareDirectory();

  Future<Directory> _prepareDirectory() async {
    final directory = await _cacheDirectory;
    await directory.create(recursive: true);

    final validEntries = <_StartupEntry>[];
    var totalBytes = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      if (entity.path.endsWith('.tmp')) {
        await _deleteBestEffort(entity);
        continue;
      }
      if (!entity.path.endsWith('.json')) continue;

      final body = File(
        '${entity.path.substring(0, entity.path.length - 5)}.png',
      );
      try {
        final metadata = _CacheMetadata.fromJson(
          jsonDecode(await entity.readAsString()),
        );
        final bodyLength = await _lengthBestEffort(body);
        if (!await body.exists() ||
            bodyLength == 0 ||
            bodyLength > _tileByteLimit ||
            bodyLength != metadata.bodyLength ||
            !_now().toUtc().isBefore(metadata.expiresAt)) {
          await _deleteBestEffort(entity);
          await _deleteBestEffort(body);
          continue;
        }
        validEntries.add(
          _StartupEntry(
            metadataFile: entity,
            bodyFile: body,
            bodyLength: bodyLength,
            expiresAt: metadata.expiresAt,
          ),
        );
        totalBytes += bodyLength;
      } catch (_) {
        await _deleteBestEffort(entity);
        await _deleteBestEffort(body);
      }
    }

    // Keep the entries with the longest remaining policy lifetime. New writes
    // are rejected at the same bound, so both startup and runtime are bounded.
    validEntries.sort(
      (left, right) => left.expiresAt.compareTo(right.expiresAt),
    );
    while (totalBytes > _cacheByteLimit && validEntries.isNotEmpty) {
      final expiredFirst = validEntries.removeAt(0);
      await _deleteBestEffort(expiredFirst.metadataFile);
      await _deleteBestEffort(expiredFirst.bodyFile);
      totalBytes -= expiredFirst.bodyLength;
    }
    final validBodies = validEntries
        .map((entry) => entry.bodyFile.path)
        .toSet();

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File &&
          entity.path.endsWith('.png') &&
          !validBodies.contains(entity.path)) {
        await _deleteBestEffort(entity);
      }
    }
    _cachedBytes = totalBytes;
    return directory;
  }

  Future<_CacheEntry?> _readEntry(
    Directory directory,
    _TileAddress address,
  ) async {
    final bodyFile = address.bodyFile(directory);
    final metadataFile = address.metadataFile(directory);
    if (!await bodyFile.exists() || !await metadataFile.exists()) return null;
    try {
      final metadata = _CacheMetadata.fromJson(
        jsonDecode(await metadataFile.readAsString()),
      );
      final body = await bodyFile.readAsBytes();
      if (body.isEmpty ||
          body.length > _tileByteLimit ||
          body.length != metadata.bodyLength) {
        throw const FormatException('invalid tile length');
      }
      return _CacheEntry(body, metadata);
    } catch (_) {
      final previousLength = await _lengthBestEffort(bodyFile);
      await _deleteBestEffort(bodyFile);
      await _deleteBestEffort(metadataFile);
      _cachedBytes = (_cachedBytes - previousLength).clamp(0, _cacheByteLimit);
      return null;
    }
  }

  Future<void> _writeEntry(
    Directory directory,
    _TileAddress address,
    List<int> body,
    _CacheMetadata metadata,
  ) async {
    final bodyFile = address.bodyFile(directory);
    await bodyFile.parent.create(recursive: true);
    await _writeBytesAtomically(bodyFile, body);
    await _writeMetadata(directory, address, metadata);
  }

  Future<void> _writeMetadata(
    Directory directory,
    _TileAddress address,
    _CacheMetadata metadata,
  ) => _writeTextAtomically(
    address.metadataFile(directory),
    jsonEncode(metadata.toJson()),
  );

  Future<void> _deleteEntry(Directory directory, _TileAddress address) async {
    final body = address.bodyFile(directory);
    final previousLength = await _lengthBestEffort(body);
    await _deleteBestEffort(body);
    await _deleteBestEffort(address.metadataFile(directory));
    _cachedBytes = (_cachedBytes - previousLength).clamp(0, _cacheByteLimit);
  }

  _CachePolicy _cachePolicy(Map<String, String> headers, DateTime now) {
    final cacheControl = headers['cache-control']?.toLowerCase();
    if (cacheControl != null) {
      final directives = cacheControl
          .split(',')
          .map((value) => value.trim())
          .toList(growable: false);
      if (directives.contains('no-store')) {
        return _CachePolicy.doNotStore(now);
      }
      if (directives.contains('no-cache')) {
        return _CachePolicy.storeUntil(now);
      }
      for (final directive in directives) {
        final match = RegExp(r'^max-age=(\d+)$').firstMatch(directive);
        if (match == null) continue;
        final maxAge = int.tryParse(match.group(1)!);
        final age = int.tryParse(headers['age'] ?? '') ?? 0;
        if (maxAge != null) {
          final remaining = (maxAge - age).clamp(0, maxAge);
          return _CachePolicy.storeUntil(now.add(Duration(seconds: remaining)));
        }
      }
    }

    final expires = headers['expires'];
    if (expires != null) {
      try {
        return _CachePolicy.storeUntil(HttpDate.parse(expires).toUtc());
      } catch (_) {}
    }
    return _CachePolicy.storeUntil(now.add(fallbackLifetime));
  }

  Future<void> _writeBytesAtomically(File target, List<int> body) async {
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsBytes(body, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Future<void> _writeTextAtomically(File target, String body) async {
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(body, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Future<int> _lengthBestEffort(File file) async {
    try {
      return await file.exists() ? await file.length() : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _deleteBestEffort(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _innerClient.close();
    super.close();
  }
}

class _TileAddress {
  const _TileAddress(this.z, this.x, this.y);

  final int z;
  final int x;
  final int y;

  String get key => '$z/$x/$y';

  File bodyFile(Directory root) => File('${root.path}/$z/$x/$y.png');

  File metadataFile(Directory root) => File('${root.path}/$z/$x/$y.json');

  static _TileAddress? tryParse(http.BaseRequest request) {
    final uri = request.url;
    if (request.method != 'GET' ||
        uri.scheme != 'https' ||
        uri.host != 'tile.openstreetmap.org' ||
        (uri.hasPort && uri.port != 443) ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.length != 3) {
      return null;
    }

    final z = int.tryParse(uri.pathSegments[0]);
    final x = int.tryParse(uri.pathSegments[1]);
    final ySegment = uri.pathSegments[2];
    if (!ySegment.endsWith('.png')) return null;
    final y = int.tryParse(ySegment.substring(0, ySegment.length - 4));
    if (z == null || x == null || y == null || z < 0 || z > 19) return null;
    final dimension = 1 << z;
    if (x < 0 || y < 0 || x >= dimension || y >= dimension) return null;
    return _TileAddress(z, x, y);
  }
}

class _CacheEntry {
  const _CacheEntry(this.body, this.metadata);

  final List<int> body;
  final _CacheMetadata metadata;
}

class _StartupEntry {
  const _StartupEntry({
    required this.metadataFile,
    required this.bodyFile,
    required this.bodyLength,
    required this.expiresAt,
  });

  final File metadataFile;
  final File bodyFile;
  final int bodyLength;
  final DateTime expiresAt;
}

class _CacheMetadata {
  const _CacheMetadata({
    required this.expiresAt,
    required this.contentType,
    required this.bodyLength,
    this.etag,
    this.lastModified,
  });

  final DateTime expiresAt;
  final String? etag;
  final String? lastModified;
  final String contentType;
  final int bodyLength;

  _CacheMetadata copyWith({
    DateTime? expiresAt,
    String? etag,
    String? lastModified,
    String? contentType,
  }) => _CacheMetadata(
    expiresAt: expiresAt ?? this.expiresAt,
    etag: etag ?? this.etag,
    lastModified: lastModified ?? this.lastModified,
    contentType: contentType ?? this.contentType,
    bodyLength: bodyLength,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'version': OsmTileCacheClient.metadataVersion,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'etag': etag,
    'lastModified': lastModified,
    'contentType': contentType,
    'bodyLength': bodyLength,
  };

  factory _CacheMetadata.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['version'] != OsmTileCacheClient.metadataVersion ||
        value['expiresAt'] is! String ||
        value['contentType'] is! String ||
        value['bodyLength'] is! int ||
        (value['bodyLength'] as int) <= 0) {
      throw const FormatException('invalid OSM tile cache metadata');
    }
    final expiresAt = DateTime.tryParse(value['expiresAt'] as String)?.toUtc();
    if (expiresAt == null) {
      throw const FormatException('invalid OSM tile cache expiry');
    }
    return _CacheMetadata(
      expiresAt: expiresAt,
      etag: value['etag'] as String?,
      lastModified: value['lastModified'] as String?,
      contentType: value['contentType'] as String,
      bodyLength: value['bodyLength'] as int,
    );
  }
}

class _CachePolicy {
  const _CachePolicy(this.store, this.expiresAt);

  factory _CachePolicy.storeUntil(DateTime expiresAt) =>
      _CachePolicy(true, expiresAt);

  factory _CachePolicy.doNotStore(DateTime now) => _CachePolicy(false, now);

  final bool store;
  final DateTime expiresAt;
}

class _ResponseSnapshot {
  const _ResponseSnapshot({
    required this.body,
    required this.statusCode,
    required this.headers,
    required this.contentLength,
    required this.isRedirect,
    required this.persistentConnection,
    this.reasonPhrase,
  });

  factory _ResponseSnapshot.cached(List<int> body, String contentType) =>
      _ResponseSnapshot(
        body: body,
        statusCode: HttpStatus.ok,
        headers: <String, String>{'content-type': contentType},
        contentLength: body.length,
        isRedirect: false,
        persistentConnection: true,
      );

  factory _ResponseSnapshot.fromUpstream(
    http.StreamedResponse response,
    List<int> body,
    Map<String, String> headers,
  ) => _ResponseSnapshot(
    body: body,
    statusCode: response.statusCode,
    headers: headers,
    contentLength: body.length,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
  );

  final List<int> body;
  final int statusCode;
  final Map<String, String> headers;
  final int contentLength;
  final bool isRedirect;
  final bool persistentConnection;
  final String? reasonPhrase;

  http.StreamedResponse toStreamedResponse(http.BaseRequest request) =>
      http.StreamedResponse(
        Stream<List<int>>.value(body),
        statusCode,
        contentLength: contentLength,
        request: request,
        headers: headers,
        isRedirect: isRedirect,
        persistentConnection: persistentConnection,
        reasonPhrase: reasonPhrase,
      );
}
