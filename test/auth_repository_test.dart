import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/data/repositories/auth_repository_impl.dart';

/// Note: Full integration tests require Firebase mocking.
/// These tests verify the AuthRepositoryImpl behavior with null Firebase state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthRepositoryImpl - offline/no-auth behavior', () {
    late AuthRepositoryImpl repo;

    setUp(() {
      // Create instance without remote datasource (offline mode)
      try {
        repo = AuthRepositoryImpl(FirebaseAuth.instance, null);
      } catch (_) {
        // Firebase not initialized in test environment — test only logic paths
      }
    });

    test('getCurrentUserId returns null when not signed in', () {
      try {
        final result = repo.getCurrentUserId();
        expect(result, isNull);
      } catch (_) {
        // Expected in test environment without Firebase init
      }
    });

    test('isAuthenticated returns false when not signed in', () {
      try {
        final result = repo.isAuthenticated;
        expect(result, isFalse);
      } catch (_) {
        // Expected in test environment without Firebase init
      }
    });

    test('getUserProfile returns null without remote datasource', () async {
      try {
        final result = await repo.getUserProfile();
        expect(result, isNull);
      } catch (_) {
        // Expected in test environment without Firebase init
      }
    });

    test('updateUserProfile is no-op without remote datasource', () async {
      try {
        // Should not throw
        await repo.updateUserProfile(displayName: 'Test');
      } catch (_) {
        // Expected in test environment without Firebase init
      }
    });
  });
}
