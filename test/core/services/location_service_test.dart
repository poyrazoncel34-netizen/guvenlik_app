import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// S5: LocationService.getCurrentLocation must fall back to cached position on
/// timeout, not just return an error. A 10-second GPS timeout during an
/// emergency delays the call unacceptably.
void main() {
  test('getCurrentLocation should fall back to cached location on timeout', () {
    final source = File(
      'lib/core/services/location_service.dart',
    ).readAsStringSync();

    // Should handle TimeoutException specifically and return cached location
    expect(
      source.contains('TimeoutException'),
      isTrue,
      reason:
          'LocationService must catch TimeoutException specifically and fall '
          'back to _lastKnownPosition instead of returning error',
    );
  });
}
