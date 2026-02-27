import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/firebase_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseRemoteDataSource? _remote;

  AuthRepositoryImpl(this._auth, [this._remote]);

  @override
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  @override
  bool get isAuthenticated => _auth.currentUser != null;

  @override
  Future<UserProfile?> getUserProfile() async {
    if (_remote == null || _auth.currentUser == null) return null;
    return _remote.getUserProfile();
  }

  @override
  Future<void> updateUserProfile({String? displayName, String? email}) async {
    if (_remote == null || _auth.currentUser == null) return;
    await _remote.updateUserProfile(
      displayName: displayName,
      email: email,
    );
  }

  @override
  Future<void> deleteAccount() async {
    if (_remote == null) {
      // Fallback: sadece Firebase Auth hesabını sil
      await _auth.currentUser?.delete();
      return;
    }
    await _remote.deleteAccount();
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }
}

