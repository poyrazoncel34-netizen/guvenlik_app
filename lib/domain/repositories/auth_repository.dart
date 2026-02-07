abstract class AuthRepository {
  String? getCurrentUserId();
  Future<void> signOut();
}
