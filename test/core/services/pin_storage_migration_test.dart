import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/pin_hasher.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage extends SecureStorage {
  _FakeSecureStorage({this.throwOnWrite = false});

  final Map<String, String> store = <String, String>{};
  final bool throwOnWrite;
  int writes = 0;

  @override
  Future<void> write({required String key, required String value}) async {
    if (throwOnWrite) throw Exception('keystore unavailable');
    writes++;
    store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => store[key];

  @override
  Future<void> delete({required String key}) async => store.remove(key);

  @override
  Future<void> deleteAll() async => store.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PinVerificationService serviceFor(
    _FakeSecureStorage storage, {
    Map<String, Object> prefs = const <String, Object>{},
  }) {
    SharedPreferences.setMockInitialValues(prefs);
    return PinVerificationService.forTesting(
      secureStorage: storage,
      preferencesLoader: SharedPreferences.getInstance,
      operationTimeout: const Duration(seconds: 5),
    );
  }

  test('a newly set PIN is stored hashed, never in readable form', () async {
    final storage = _FakeSecureStorage();
    final service = serviceFor(storage);

    expect(await service.writePin('4821'), isTrue);

    final stored = storage.store[SecureStorageKeys.userPin]!;
    expect(stored.contains('4821'), isFalse);
    expect(PinHasher.isLegacyPlaintext(stored), isFalse);
    expect((await service.verify('4821')).matches, isTrue);
    expect((await service.verify('1234')).matches, isFalse);
  });

  test('an existing user with a raw stored PIN can still unlock', () async {
    final storage = _FakeSecureStorage();
    storage.store[SecureStorageKeys.userPin] = '4821';
    final service = serviceFor(storage);

    final result = await service.verify('4821');

    expect(
      result.matches,
      isTrue,
      reason:
          'The migration must never force an existing user to re-enrol; '
          'locking someone out of their own safety app is the worst possible '
          'outcome of a storage hardening change.',
    );
    expect(result.state, PinState.configured);
  });

  test('the raw PIN is upgraded in place on first successful unlock', () async {
    final storage = _FakeSecureStorage();
    storage.store[SecureStorageKeys.userPin] = '4821';
    final service = serviceFor(storage);

    await service.verify('4821');

    final stored = storage.store[SecureStorageKeys.userPin]!;
    expect(PinHasher.isLegacyPlaintext(stored), isFalse);
    expect(stored.contains('4821'), isFalse);
    expect((await service.verify('4821')).matches, isTrue);
  });

  test('a wrong PIN never triggers an upgrade write', () async {
    final storage = _FakeSecureStorage();
    storage.store[SecureStorageKeys.userPin] = '4821';
    final service = serviceFor(storage);
    final writesBefore = storage.writes;

    expect((await service.verify('9999')).matches, isFalse);

    expect(storage.writes, writesBefore);
    expect(storage.store[SecureStorageKeys.userPin], '4821');
  });

  test('a legacy SharedPreferences PIN migrates as a hash, not raw', () async {
    final storage = _FakeSecureStorage();
    final service = serviceFor(
      storage,
      prefs: <String, Object>{SecureStorageKeys.userPin: '4821'},
    );

    expect(await service.loadState(), PinState.configured);

    final stored = storage.store[SecureStorageKeys.userPin]!;
    expect(PinHasher.isLegacyPlaintext(stored), isFalse);
    expect(stored.contains('4821'), isFalse);
    expect((await service.verify('4821')).matches, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SecureStorageKeys.userPin), isNull);
  });

  test('a failed write is reported, never silently accepted', () async {
    final storage = _FakeSecureStorage(throwOnWrite: true);
    final service = serviceFor(storage);

    expect(
      await service.writePin('4821'),
      isFalse,
      reason:
          'The caller marks PIN setup done and tells the user they are '
          'protected. A swallowed failure hands them a lock that does not '
          'exist.',
    );
    expect(storage.store[SecureStorageKeys.userPin], isNull);
  });

  test('the PIN setup screen refuses to claim success on a failed save', () {
    final source = File(
      'lib/screens/pin_setup_screen.dart',
    ).readAsStringSync();
    final saveIndex = source.indexOf('writePin(_pin)');
    final doneIndex = source.indexOf('prefPinSetupDone');
    expect(saveIndex, greaterThan(-1));
    expect(doneIndex, greaterThan(saveIndex));
    expect(source, contains('if (!saved)'));
    expect(source, contains('pin_setup_save_failed'));
  });
}
