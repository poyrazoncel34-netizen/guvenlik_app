import 'package:flutter/foundation.dart';

/// Why the map tile layer cannot currently be shown.
enum MapTileOutage {
  /// The tile server refused us (401/403/429). OSMF says access "may be
  /// blocked without notice"; a paid provider answers the same codes for a
  /// bad key or an exhausted quota.
  blocked,

  /// Timeouts, socket/TLS failures, or 5xx answers in a row.
  network,
}

/// Observable health of the optional map tile layer.
///
/// `null` means tiles are (as far as we know) loading normally. The map page
/// listens to this to show its "map can't be loaded right now" state instead
/// of a silently blank map.
///
/// Fed ONLY from the HTTP boundary (`OsmTileCacheClient`); nothing on the
/// emergency path reads or writes it.
class MapTileAvailability extends ValueNotifier<MapTileOutage?> {
  MapTileAvailability() : super(null);

  /// One slow tile is not an outage; this many failures with no success in
  /// between is.
  static const int networkFailureThreshold = 3;

  int _consecutiveNetworkFailures = 0;
  bool _disposed = false;

  /// An upstream answer that carries a tile (2xx) or confirms one (304).
  void reportSuccess() {
    if (_disposed) return;
    _consecutiveNetworkFailures = 0;
    value = null;
  }

  void reportBlocked() {
    if (_disposed) return;
    _consecutiveNetworkFailures = 0;
    value = MapTileOutage.blocked;
  }

  void reportNetworkFailure() {
    if (_disposed) return;
    _consecutiveNetworkFailures++;
    // A refusal is the stronger, more specific signal; a timeout that follows
    // it must not relabel the outage as "check your connection".
    if (value == MapTileOutage.blocked) return;
    if (_consecutiveNetworkFailures >= networkFailureThreshold) {
      value = MapTileOutage.network;
    }
  }

  // Tile requests can complete after the map page is gone (NetworkTileProvider
  // waits for in-flight requests before closing the client). Reports after
  // that point are dropped instead of tripping ValueNotifier's
  // used-after-dispose assertion.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
