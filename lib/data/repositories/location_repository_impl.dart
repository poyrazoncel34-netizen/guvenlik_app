import 'package:latlong2/latlong.dart';
import '../../core/services/location_service.dart';
import '../../domain/repositories/location_repository.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationService _locationService;

  LocationRepositoryImpl(this._locationService);

  @override
  Future<LocationResult> getCurrentLocation({bool highAccuracy = true}) {
    return _locationService.getCurrentLocation(highAccuracy: highAccuracy);
  }

  @override
  Future<LocationResult> getLastKnownLocation() {
    return _locationService.getLastKnownLocation();
  }

  @override
  Stream<dynamic>? getPositionStream({
    bool highAccuracy = true,
    int distanceFilter = 10,
  }) {
    return _locationService.getPositionStream(
      highAccuracy: highAccuracy,
      distanceFilter: distanceFilter,
    );
  }

  @override
  Future<bool> openAppSettings() {
    return _locationService.openAppSettings();
  }

  @override
  Future<bool> openLocationSettings() {
    return _locationService.openLocationSettings();
  }

  @override
  LatLng get lastKnownPosition => _locationService.lastKnownPosition;
}
