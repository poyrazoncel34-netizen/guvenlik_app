import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('map tiles use and dispose the persistent OSM cache client', () {
    final source = File('lib/screens/map_page.dart').readAsStringSync();

    expect(
      source,
      contains('OsmTileCacheClient(availability: _tileAvailability)'),
    );
    expect(source, contains('tileProvider: _osmTileProvider'));
    expect(source, contains('unawaited(_osmTileProvider.dispose())'));
    expect(source, contains('AppEnvironment.mapTileUrlTemplate'));
    // Tile failures are silenced into transparent tiles and surfaced through
    // MapTileAvailability; an errorTileCallback would now be dead code.
    expect(source, contains('silenceExceptions: true'));
    expect(source, isNot(contains('errorTileCallback')));
    expect(source, isNot(contains("debugPrint('TileLayer error")));
  });
}
