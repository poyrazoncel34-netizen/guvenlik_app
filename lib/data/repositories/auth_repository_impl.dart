import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth;

  AuthRepositoryImpl(this._auth);

  @override
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }
}
