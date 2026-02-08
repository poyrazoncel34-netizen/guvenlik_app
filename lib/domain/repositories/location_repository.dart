import 'package:latlong2/latlong.dart';
import '../../core/services/location_service.dart';

abstract class LocationRepository {
  Future<LocationResult> getCurrentLocation({bool highAccuracy = true});
  Future<LocationResult> getLastKnownLocation();
  Stream<dynamic>? getPositionStream({
    bool highAccuracy = true,
    int distanceFilter = 10,
  });
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
  LatLng get lastKnownPosition;
}
