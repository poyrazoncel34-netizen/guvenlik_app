import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'withdrawn consent blocks every GPS read before platform access',
    () async {
      final service = LocationService.forTesting(consentAllowed: () => false);

      final current = await service.getCurrentLocation();
      final lastKnown = await service.getLastKnownLocation();

      expect(current.status, LocationStatus.consentDenied);
      expect(lastKnown.status, LocationStatus.consentDenied);
      expect(service.getPositionStream(), isNull);
      expect(service.lastKnownPosition, isNull);
    },
  );
}
