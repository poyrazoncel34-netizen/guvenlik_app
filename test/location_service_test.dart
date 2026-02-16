import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/location_service.dart';

void main() {
  group('LocationService', () {
    test('factory returns same instance', () {
      final instance1 = LocationService();
      final instance2 = LocationService();
      expect(identical(instance1, instance2), true);
    });

    test('defaultLocation is Istanbul', () {
      expect(LocationService.defaultLocation.latitude, closeTo(41.0, 0.1));
      expect(LocationService.defaultLocation.longitude, closeTo(29.0, 0.1));
    });

    test('lastKnownPosition returns default when null', () {
      final service = LocationService();
      expect(service.lastKnownPosition, LocationService.defaultLocation);
    });
  });

  group('LocationResult', () {
    test('isSuccess returns true for success with position', () {
      final result = LocationResult(
        status: LocationStatus.success,
        position: LocationService.defaultLocation,
      );
      expect(result.isSuccess, true);
    });

    test('isSuccess returns false for error', () {
      final result = LocationResult(
        status: LocationStatus.error,
        errorMessage: 'Test error',
      );
      expect(result.isSuccess, false);
    });

    test('isSuccess returns false for permission denied', () {
      final result = LocationResult(
        status: LocationStatus.permissionDenied,
      );
      expect(result.isSuccess, false);
    });
  });
}
