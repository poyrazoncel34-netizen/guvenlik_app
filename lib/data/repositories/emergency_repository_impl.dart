import '../../domain/repositories/emergency_repository.dart';
import '../datasources/remote/firebase_datasource.dart';

class EmergencyRepositoryImpl implements EmergencyRepository {
  final FirebaseRemoteDataSource _remote;

  EmergencyRepositoryImpl(this._remote);

  @override
  Future<void> createEmergencyEvent({
    required String title,
    required String message,
    required double? lat,
    required double? lng,
  }) {
    return _remote.createEmergencyEvent(
      title: title,
      message: message,
      lat: lat,
      lng: lng,
    );
  }

  @override
  Future<void> updateLocation({required double lat, required double lng}) {
    return _remote.updateLocation(lat: lat, lng: lng);
  }

  @override
  Future<List<Map<String, dynamic>>> getEmergencyHistory({int limit = 20}) {
    return _remote.getEmergencyHistory(limit: limit);
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveEmergencies() {
    return _remote.getActiveEmergencies();
  }
}

