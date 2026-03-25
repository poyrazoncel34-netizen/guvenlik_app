import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';

void main() {
  group('SecureStorage', () {
    test('uses encrypted shared preferences on Android', () {
      expect(SecureStorage.encryptedPrefsEnabled, isTrue);
    });
  });
}
