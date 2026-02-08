import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    test('without key - encrypt returns base64 of plaintext', () {
      final service = EncryptionService();
      expect(service.isReady, false);
      final result = service.encrypt('test');
      expect(result, isNotEmpty);
    });
    test('without key - decrypt handles plain base64', () {
      final service = EncryptionService();
      final encoded = service.encrypt('hello');
      final decoded = service.decrypt(encoded);
      expect(decoded, 'hello');
    });
  });
}
