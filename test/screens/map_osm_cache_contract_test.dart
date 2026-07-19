import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('map tiles use and dispose the persistent OSM cache client', () {
    final source = File('lib/screens/map_page.dart').readAsStringSync();

    expect(source, contains('OsmTileCacheClient()'));
    expect(source, contains('tileProvider: _osmTileProvider'));
    expect(source, contains('unawaited(_osmTileProvider.dispose())'));
    expect(source, contains('AppEnvironment.mapTileUrlTemplate'));
    expect(source, contains('MAP_TILE_LOAD_FAILED_REDACTED'));
    expect(source, isNot(contains("debugPrint('TileLayer error")));
  });
}
