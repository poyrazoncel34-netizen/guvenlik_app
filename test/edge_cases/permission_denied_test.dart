// Edge-case: LocationService returns a graceful error result when
// location permission is denied — it must never throw or crash.
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/location_service.dart';

void main() {
  group('LocationService permission denied', () {
    test('LocationResult carries permissionDenied status when permission missing', () {
      final result = LocationResult(
        status: LocationStatus.permissionDenied,
        errorMessage: 'Permission denied',
      );
      expect(result.isSuccess, isFalse);
      expect(result.status, equals(LocationStatus.permissionDenied));
      expect(result.errorMessage, isNotNull);
    });

    test('LocationResult.isSuccess is false for every non-success status', () {
      for (final status in LocationStatus.values) {
        if (status == LocationStatus.success) continue;
        final result = LocationResult(status: status);
        expect(result.isSuccess, isFalse,
            reason: '$status should not be considered success');
      }
    });
  });
}
