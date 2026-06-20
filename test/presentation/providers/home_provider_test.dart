import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// S6 regression: the non-functional "location session" (location sharing)
/// feature was removed from HomeProvider. The free location/permission API and
/// the general pending-message hook must stay.
void main() {
  group('HomeProvider location-session removal', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/presentation/providers/home_provider.dart',
      ).readAsStringSync();
    });

    test('location-sharing API is fully removed', () {
      for (final symbol in const [
        'startLocationSharing',
        'stopLocationSharing',
        'isLocationSharing',
        '_locationShareTimer',
        'locationShared',
      ]) {
        expect(
          source.contains(symbol),
          isFalse,
          reason: '$symbol must be gone after location-session removal',
        );
      }
    });

    test('free location permission API and message hook are preserved', () {
      expect(source, contains('requestLocationPermission'));
      expect(source, contains('locationPermissionGranted'));
      expect(source, contains('String? takeMessage()'));
    });
  });
}
