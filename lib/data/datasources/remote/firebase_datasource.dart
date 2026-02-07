import '../../../core/services/firebase_service.dart';

class FirebaseRemoteDataSource {
  final FirebaseService _firebaseService;

  FirebaseRemoteDataSource(this._firebaseService);

  Future<void> upsertUserProfile() {
    return _firebaseService.upsertUserProfile();
  }

  Future<void> createEmergencyEvent({
    required String title,
    required String message,
    required double? lat,
    required double? lng,
  }) {
    return _firebaseService.createEmergencyEvent(
      title: title,
      message: message,
      lat: lat,
      lng: lng,
    );
  }

  Future<void> updateLocation({
    required double lat,
    required double lng,
  }) {
    return _firebaseService.updateLocation(lat: lat, lng: lng);
  }
}
