import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage extends SecureStorage {
  final Map<String, String> values = <String, String>{};
  Object? readError;

  @override
  Future<String?> read({required String key}) async {
    if (readError != null) throw readError!;
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }
}

class _NonPersistingSecureStorage extends _FakeSecureStorage {
  @override
  Future<void> write({required String key, required String value}) async {}
}

class _HangingSecureStorage extends _FakeSecureStorage {
  @override
  Future<String?> read({required String key}) => Completer<String?>().future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loading and read failure never collapse into absent', () async {
    final storage = _FakeSecureStorage()..readError = StateError('locked');
    final service = PinVerificationService.forTesting(secureStorage: storage);

    expect(service.state, PinState.loading);
    expect(await service.loadState(), PinState.readFailed);
    final verification = await service.verify('1234');
    expect(verification.state, PinState.readFailed);
    expect(verification.matches, isFalse);
  });

  test('hanging secure storage is bounded and fails closed', () async {
    final service = PinVerificationService.forTesting(
      secureStorage: _HangingSecureStorage(),
      operationTimeout: const Duration(milliseconds: 20),
    );

    expect(
      await service.loadState().timeout(const Duration(milliseconds: 200)),
      PinState.readFailed,
    );
    expect(service.state, PinState.readFailed);
  });

  test(
    'absent is returned only after successful secure and legacy reads',
    () async {
      final service = PinVerificationService.forTesting(
        secureStorage: _FakeSecureStorage(),
      );

      expect(await service.loadState(), PinState.absent);
    },
  );

  test('configured PIN is verified without exposing its value', () async {
    final storage = _FakeSecureStorage()
      ..values[SecureStorageKeys.userPin] = '4826';
    final service = PinVerificationService.forTesting(secureStorage: storage);

    expect(await service.loadState(), PinState.configured);
    expect((await service.verify('4826')).matches, isTrue);
    expect((await service.verify('4827')).matches, isFalse);
    expect(service.state, PinState.configured);
  });

  test('legacy PIN is migrated before configured is acknowledged', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SecureStorageKeys.userPin: '2468',
    });
    final storage = _FakeSecureStorage();
    final service = PinVerificationService.forTesting(secureStorage: storage);

    expect(await service.loadState(), PinState.configured);
    expect(storage.values[SecureStorageKeys.userPin], '2468');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(SecureStorageKeys.userPin), isFalse);
  });

  test('empty candidate never reads or implicitly configures a PIN', () async {
    final storage = _FakeSecureStorage()
      ..values[SecureStorageKeys.userPin] = '4826';
    final service = PinVerificationService.forTesting(secureStorage: storage);

    final result = await service.verify('');

    expect(result.state, PinState.loading);
    expect(result.matches, isFalse);
  });

  test('verification without a configured or legacy PIN is absent', () async {
    final service = PinVerificationService.forTesting(
      secureStorage: _FakeSecureStorage(),
    );

    final result = await service.verify('1234');

    expect(result.state, PinState.absent);
    expect(result.matches, isFalse);
  });

  test(
    'migration acknowledgement without a durable PIN fails closed',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SecureStorageKeys.userPin: '2468',
      });
      final service = PinVerificationService.forTesting(
        secureStorage: _NonPersistingSecureStorage(),
      );

      final result = await service.verify('2468');

      expect(result.state, PinState.readFailed);
      expect(result.matches, isFalse);
    },
  );

  test(
    'constant-time comparison handles shorter and longer candidates',
    () async {
      final storage = _FakeSecureStorage()
        ..values[SecureStorageKeys.userPin] = '4826';
      final service = PinVerificationService.forTesting(secureStorage: storage);

      expect((await service.verify('482')).matches, isFalse);
      expect((await service.verify('48260')).matches, isFalse);
    },
  );
}
