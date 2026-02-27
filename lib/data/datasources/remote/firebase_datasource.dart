import '../../../core/services/firebase_service.dart';
import '../../../domain/models/user_profile.dart';

class FirebaseRemoteDataSource {
  final FirebaseService _firebaseService;

  FirebaseRemoteDataSource(this._firebaseService);

  Future<void> upsertUserProfile() {
    return _firebaseService.upsertUserProfile();
  }

  Future<UserProfile?> getUserProfile() {
    return _firebaseService.getUserProfile();
  }

  Future<void> updateUserProfile({String? displayName, String? email}) {
    return _firebaseService.updateUserProfile(
      displayName: displayName,
      email: email,
    );
  }

  Future<void> deleteAccount() {
    return _firebaseService.deleteAccount();
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

  Future<void> updateLocation({required double lat, required double lng}) {
    return _firebaseService.updateLocation(lat: lat, lng: lng);
  }

  Future<List<Map<String, dynamic>>> getEmergencyHistory({int limit = 20}) {
    return _firebaseService.getEmergencyHistory(limit: limit);
  }

  Future<List<Map<String, dynamic>>> getActiveEmergencies() {
    return _firebaseService.getActiveEmergencies();
  }
}
