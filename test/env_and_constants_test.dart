import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:guvenlik_app/core/config/app_environment.dart';
import 'package:guvenlik_app/core/constants/api_constants.dart';
import 'package:guvenlik_app/core/services/location_service.dart';

void main() {
  group('AppEnvironment', () {
    test('default env is dev', () {
      expect(AppEnvironment.isDev, isTrue);
      expect(AppEnvironment.isProduction, isFalse);
    });
    test('apiBaseUrl is non-empty', () {
      expect(AppEnvironment.apiBaseUrl, isNotEmpty);
    });
  });

  group('ApiConstants', () {
    test('baseUrl matches environment', () {
      expect(ApiConstants.baseUrl, equals(AppEnvironment.apiBaseUrl));
    });
    test('endpoints are defined', () {
      expect(ApiConstants.emergency, equals('/emergency'));
      expect(ApiConstants.contacts, equals('/contacts'));
    });
  });

  group('LocationResult', () {
    test('isSuccess is false when position is null', () {
      final result = LocationResult(
        status: LocationStatus.success,
        position: null,
      );
      expect(result.isSuccess, isFalse);
    });
    test('isSuccess is true when position is set', () {
      final result = LocationResult(
        status: LocationStatus.success,
        position: const LatLng(41.0, 29.0),
      );
      expect(result.isSuccess, isTrue);
    });
  });
}
