import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/biometric_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('BiometricService', () {
    late BiometricService service;

    setUp(() {
      service = BiometricService.instance;
    });

    test('singleton instance is consistent', () {
      final instance1 = BiometricService.instance;
      final instance2 = BiometricService.instance;
      expect(identical(instance1, instance2), true);
    });

    test('isAvailable returns bool without crashing', () async {
      // This tests the error handling - on test environment it should return false
      final result = await service.isAvailable();
      expect(result, isA<bool>());
    });

    test('getAvailableBiometrics returns list without crashing', () async {
      final result = await service.getAvailableBiometrics();
      expect(result, isA<List>());
    });

    test('getBiometricLabel returns string', () async {
      final result = await service.getBiometricLabel();
      expect(result, isA<String>());
      expect(result.isNotEmpty, true);
    });
  });
}
