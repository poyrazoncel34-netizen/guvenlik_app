import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/encryption_service.dart';

void main() {
  group('EncryptionService (no key)', () {
    late EncryptionService service;

    setUp(() {
      service = EncryptionService();
    });

    test('isReady returns false when no key configured', () {
      // In test env ENCRYPTION_KEY is not set via --dart-define
      expect(service.isReady, isFalse);
    });

    test('encrypt fails closed when no key', () {
      expect(() => service.encrypt('hello world'), throwsStateError);
    });

    test('decrypt fails closed when no key', () {
      final encoded = base64Encode(utf8.encode('test data'));
      expect(() => service.decrypt(encoded), throwsStateError);
    });

    test('legacy base64 decoding is explicit and separate', () {
      final encoded = base64Encode(utf8.encode('test data'));
      expect(service.tryDecodeLegacyBase64(encoded), 'test data');
      expect(service.tryDecodeLegacyBase64('not-valid-base64!!!'), isNull);
    });
  });
}
