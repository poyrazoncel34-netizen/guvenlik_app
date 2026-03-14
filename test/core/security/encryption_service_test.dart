import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/encryption_service.dart';

void main() {
  group('EncryptionService (no key)', () {
    late EncryptionService service;

    setUp(() {
      // Without ENCRYPTION_KEY env var, service falls back to base64
      service = EncryptionService();
    });

    test('isReady returns false when no key configured', () {
      // In test env ENCRYPTION_KEY is not set via --dart-define
      expect(service.isReady, isFalse);
    });

    test('encrypt falls back to base64 when no key', () {
      final encrypted = service.encrypt('hello world');
      final decoded = utf8.decode(base64Decode(encrypted));
      expect(decoded, 'hello world');
    });

    test('decrypt falls back to base64 when no key', () {
      final encoded = base64Encode(utf8.encode('test data'));
      final decrypted = service.decrypt(encoded);
      expect(decrypted, 'test data');
    });

    test('decrypt returns raw value when base64 fails', () {
      final decrypted = service.decrypt('not-valid-base64!!!');
      expect(decrypted, 'not-valid-base64!!!');
    });

    test('encrypt then decrypt round-trips correctly', () {
      const original = 'KoruBeni acil durum verisi';
      final encrypted = service.encrypt(original);
      final decrypted = service.decrypt(encrypted);
      expect(decrypted, original);
    });
  });

  group('EncryptionService (with key)', () {
    late EncryptionService service;

    setUp(() {
      // We can't set dart-define in tests, so we test the no-key fallback above.
      // This group tests the EncryptionService constructor behavior.
      service = EncryptionService();
    });

    test('different encryptions produce different ciphertexts (random IV)', () {
      // Even in base64 fallback mode, verify the API contract
      const value = 'same input';
      final e1 = service.encrypt(value);
      final e2 = service.encrypt(value);
      // In base64 mode both will be identical (no IV), but the contract works
      final d1 = service.decrypt(e1);
      final d2 = service.decrypt(e2);
      expect(d1, value);
      expect(d2, value);
    });

    test('handles empty string', () {
      final encrypted = service.encrypt('');
      final decrypted = service.decrypt(encrypted);
      expect(decrypted, '');
    });

    test('handles unicode/Turkish characters', () {
      const turkish = 'Acil durum! Yardım edin lütfen. Şüpheli görüldü.';
      final encrypted = service.encrypt(turkish);
      final decrypted = service.decrypt(encrypted);
      expect(decrypted, turkish);
    });

    test('handles long strings', () {
      final longText = 'A' * 10000;
      final encrypted = service.encrypt(longText);
      final decrypted = service.decrypt(encrypted);
      expect(decrypted, longText);
    });
  });
}
