import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/services/secure_storage_service.dart';

void main() {
  group('SecureStorageService', () {
    test('has static write method', () {
      expect(SecureStorageService.write, isA<Function>());
    });

    test('has static read method', () {
      expect(SecureStorageService.read, isA<Function>());
    });

    test('has static delete method', () {
      expect(SecureStorageService.delete, isA<Function>());
    });

    test('has static deleteAll method', () {
      expect(SecureStorageService.deleteAll, isA<Function>());
    });
  });
}
