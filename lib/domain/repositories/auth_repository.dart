import '../models/user_profile.dart';

abstract class AuthRepository {
  String? getCurrentUserId();
  bool get isAuthenticated;
  Future<UserProfile?> getUserProfile();
  Future<void> updateUserProfile({String? displayName, String? email});
  Future<void> deleteAccount();
  Future<void> signOut();
}
