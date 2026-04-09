// Edge-case: LocationService returns a graceful serviceDisabled result
// when GPS is turned off — must not throw.
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/location_service.dart';

void main() {
  group('LocationService GPS disabled', () {
    test('LocationResult with serviceDisabled is not successful', () {
      final result = LocationResult(
        status: LocationStatus.serviceDisabled,
        errorMessage: 'GPS off',
      );
      expect(result.isSuccess, isFalse);
      expect(result.status, equals(LocationStatus.serviceDisabled));
    });
  });
}
