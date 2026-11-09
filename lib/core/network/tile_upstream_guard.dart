import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'map_tile_availability.dart';

/// The single path from the tile cache client to the network: timeouts,
/// refusal backoff and outcome reporting for every upstream tile request.
///
/// Split out of [OsmTileCacheClient] (which keeps the cache) so neither file
/// crosses the 800-line limit. Optional map layer only; nothing on the
/// emergency path goes through here.
class TileUpstreamGuard {
  TileUpstreamGuard({
    required http.BaseClient inner,
    required DateTime Function() now,
    required Duration timeout,
    MapTileAvailability? availability,
  }) : _inner = inner,
       _now = now,
       _timeout = timeout,
       _availability = availability;

  static const String timeoutMessage = 'MAP_TILE_UPSTREAM_TIMEOUT';
  static const String backoffMessage = 'MAP_TILE_UPSTREAM_BACKOFF';
  static const String tooLargeMessage = 'OSM_TILE_RESPONSE_TOO_LARGE';

  final http.BaseClient _inner;
  final DateTime Function() _now;
  final Duration _timeout;
  final MapTileAvailability? _availability;
  final TileUpstreamBackoff _backoff = TileUpstreamBackoff();

  /// Until when upstream traffic is suspended after a refusal.
  DateTime? get suspendedUntil => _backoff.openUntil;

  bool isSuspended() => _backoff.isOpen(_now().toUtc());

  /// For non-OSM templates (a configured provider): no cache, same guard.
  Future<http.StreamedResponse> passthrough(http.BaseRequest request) async {
    final now = _now().toUtc();
    if (_backoff.isOpen(now)) throw suspendedException(request);
    final response = await send(request);
    final body = response.stream
        .timeout(
          _timeout,
          onTimeout: (sink) {
            sink.addError(http.ClientException(timeoutMessage, request.url));
            sink.close();
          },
        )
        .transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleError: (error, stack, sink) {
              if (error is http.ClientException || error is IOException) {
                _availability?.reportNetworkFailure();
              }
              sink.addError(error, stack);
            },
            handleDone: (sink) {
              recordSuccess(response.statusCode);
              sink.close();
            },
          ),
        );
    return http.StreamedResponse(
      body,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final pending = _inner.send(request);
    final http.StreamedResponse response;
    try {
      response = await pending.timeout(_timeout);
    } on TimeoutException {
      // The request cannot be cancelled; drain whatever arrives late so the
      // connection is released instead of held open. A late REFUSAL still
      // counts: ignoring it would keep hitting a server that said stop.
      pending.then((orphan) {
        _recordRefusal(orphan);
        return orphan.stream.drain<void>();
      }).ignore();
      _availability?.reportNetworkFailure();
      throw http.ClientException(timeoutMessage, request.url);
    } on IOException {
      _availability?.reportNetworkFailure();
      rethrow;
    } on http.ClientException {
      _availability?.reportNetworkFailure();
      rethrow;
    }
    _recordOutcome(response);
    return response;
  }

  static bool isServerFailure(int status) =>
      TileUpstreamBackoff.refusalStatusCodes.contains(status) || status >= 500;

  /// Anchored to when the ANSWER arrived, not when the request left: a 14 s
  /// round trip must not shorten the server's Retry-After by 14 s.
  bool _recordRefusal(http.StreamedResponse response) {
    final status = response.statusCode;
    if (!TileUpstreamBackoff.refusalStatusCodes.contains(status)) return false;
    _backoff.open(status, response.headers['retry-after'], _now().toUtc());
    _availability?.reportBlocked();
    return true;
  }

  /// Refusals and 5xx are known from the status line. Success is NOT: it is
  /// recorded only once the body has arrived ([_recordSuccess]), otherwise a
  /// 200 whose body then dies would reset the failure count every time.
  void _recordOutcome(http.StreamedResponse response) {
    if (_recordRefusal(response)) return;
    if (response.statusCode >= 500) _availability?.reportNetworkFailure();
  }

  void recordSuccess(int status) {
    final ok =
        (status >= 200 && status < 300) || status == HttpStatus.notModified;
    // A success that was already in flight when a refusal arrived must not
    // clear the "blocked" state while traffic is still suspended.
    if (ok && !_backoff.isOpen(_now().toUtc())) {
      _availability?.reportSuccess();
    }
  }

  Future<List<int>> readBody(
    http.BaseRequest request,
    Stream<List<int>> stream,
    Future<List<int>> Function(Stream<List<int>>) readBounded,
  ) async {
    // An idle timeout ON THE STREAM, not on the Future: the TimeoutException
    // arrives as an error event, which ends the await-for and cancels the
    // subscription, releasing the connection. Future.timeout would leave the
    // read (and the socket) alive for as long as the server stays silent.
    try {
      return await readBounded(stream.timeout(_timeout));
    } on TimeoutException {
      _availability?.reportNetworkFailure();
      throw http.ClientException(timeoutMessage, request.url);
    } on IOException {
      _availability?.reportNetworkFailure();
      rethrow;
    } on http.ClientException catch (error) {
      // IOClient wraps mid-body socket resets as ClientException; an
      // oversized tile is a bad tile, not a bad network.
      if (error.message != tooLargeMessage) {
        _availability?.reportNetworkFailure();
      }
      rethrow;
    }
  }

  http.ClientException suspendedException(http.BaseRequest request) =>
      http.ClientException(backoffMessage, request.url);

  void close() => _inner.close();
}

/// Stops ALL upstream tile traffic for a while after the server refuses us.
///
/// Without this, a 429/403 is answered by flutter_map requesting the next
/// tile, and the next: every pan re-hits a server that has just told us to
/// stop. That is exactly the traffic pattern that turns a rate limit into a
/// block. While open, cached tiles may still be served; nothing goes out.
class TileUpstreamBackoff {
  static const Set<int> refusalStatusCodes = <int>{401, 403, 429};
  static const Duration rateLimitedDefault = Duration(minutes: 5);
  static const Duration refusedDefault = Duration(minutes: 30);
  static const Duration minimum = Duration(seconds: 30);
  static const Duration maximum = Duration(hours: 1);

  DateTime? _until;

  bool isOpen(DateTime now) {
    final until = _until;
    // A block further ahead than [maximum] can only mean the wall clock was
    // moved back; it must not stretch a one-hour block into a day.
    return until != null &&
        now.isBefore(until) &&
        !until.isAfter(now.add(maximum));
  }

  /// When upstream traffic may resume; `null` when it never stopped.
  DateTime? get openUntil => _until;

  void open(int statusCode, String? retryAfter, DateTime now) {
    final until = now.add(durationFor(statusCode, retryAfter, now));
    final current = _until;
    // A later, shorter Retry-After never shortens a block already in force.
    if (current == null || !isOpen(now) || until.isAfter(current)) {
      _until = until;
    }
  }

  /// Honours `Retry-After` (delta-seconds or HTTP-date), bounded so a hostile
  /// or broken header can neither hammer (0 s) nor disable the map for days.
  static Duration durationFor(
    int statusCode,
    String? retryAfter,
    DateTime now,
  ) {
    Duration? requested;
    final raw = retryAfter?.trim();
    if (raw != null && raw.isNotEmpty) {
      final seconds = int.tryParse(raw);
      if (seconds != null) {
        // Clamp BEFORE building the Duration: a huge value would overflow the
        // microsecond count, wrap negative and land on the 30 s minimum.
        requested = seconds > maximum.inSeconds
            ? maximum
            : Duration(seconds: seconds);
      } else {
        try {
          requested = HttpDate.parse(raw).toUtc().difference(now.toUtc());
        } on HttpException {
          requested = null;
        } on FormatException {
          requested = null;
        }
      }
    }
    final chosen =
        requested ??
        (statusCode == HttpStatus.tooManyRequests
            ? rateLimitedDefault
            : refusedDefault);
    if (chosen < minimum) return minimum;
    if (chosen > maximum) return maximum;
    return chosen;
  }
}
