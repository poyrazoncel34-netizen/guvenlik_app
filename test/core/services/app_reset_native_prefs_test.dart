import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/app_reset_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KVKK Md.7 (silme): "Verilerimi Sil" must also wipe the NATIVE
/// korubeni_emergency SharedPreferences, which holds the primary contact
/// number (KEY_CHECK_IN_PRIMARY_NUMBER / KEY_COUNTDOWN_PRIMARY_NUMBER). The
/// Dart-side prefs.clear() only touches the Flutter-managed store. Reset must
/// first receive a typed native wipe acknowledgement; Unknown/TooLate cannot
/// be presented as deletion success.
class _FakeSecureStorage extends SecureStorage {
  bool deleteCalled = false;

  @override
  Future<void> deleteAll() async {
    deleteCalled = true;
  }
}

class _FakeLocalDatabaseService extends LocalDatabaseService {
  @override
  Future<void> deleteDatabaseFile() async {}
}

class _FaultingLocalResetStore implements AppResetLocalDataStore {
  _FaultingLocalResetStore({
    this.preferencesCleared = true,
    this.secureStorageThrows = false,
    this.filesCleared = true,
    this.onClearSecureStorage,
  });

  final bool preferencesCleared;
  final bool secureStorageThrows;
  final bool filesCleared;
  final Future<void> Function()? onClearSecureStorage;
  final List<String> operations = [];

  @override
  Future<bool> clearPreferences() async {
    operations.add('preferences');
    return preferencesCleared;
  }

  @override
  Future<void> clearSecureStorage() async {
    operations.add('secureStorage');
    if (secureStorageThrows) throw StateError('PIN=8642 phone=+905551112233');
    await onClearSecureStorage?.call();
  }

  @override
  Future<void> deleteDatabase() async {
    operations.add('database');
  }

  @override
  Future<bool> clearLocalFiles() async {
    operations.add('files');
    return filesCleared;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.poyrazoncel.korubeni/emergency_platform');
  final invoked = <String>[];
  late _FakeSecureStorage secure;
  Map<String, Object?>? wipeResponse;

  setUp(() async {
    invoked.clear();
    wipeResponse = <String, Object?>{'type': 'completed'};
    SharedPreferences.setMockInitialValues(<String, Object>{'seed': 1});
    await serviceLocator.reset();
    secure = _FakeSecureStorage();
    serviceLocator.registerSingleton<SecureStorage>(secure);
    serviceLocator.registerSingleton<LocalDatabaseService>(
      _FakeLocalDatabaseService(),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          invoked.add(call.method);
          if (call.method == 'wipeEmergencySessions') return wipeResponse;
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await serviceLocator.reset();
  });

  test(
    'clearLocalData requires a completed typed native wipe (KVKK Md.7)',
    () async {
      final result = await AppResetService.clearLocalData(
        localStore: _FaultingLocalResetStore(
          onClearSecureStorage: secure.deleteAll,
        ),
      );
      expect(result, WipeResult.completed);
      expect(
        invoked,
        contains('wipeEmergencySessions'),
        reason: 'reset must atomically cancel/wipe native session state',
      );
      expect(invoked, isNot(contains('clearEmergencyPrefs')));
      expect(secure.deleteCalled, isTrue);
    },
  );

  test('Unknown native wipe leaves local data intact and pending', () async {
    wipeResponse = <String, Object?>{'type': 'unknown'};

    final result = await AppResetService.clearLocalData();

    expect(result, WipeResult.unknown);
    expect(secure.deleteCalled, isFalse);
    expect((await SharedPreferences.getInstance()).getInt('seed'), 1);
  });

  test(
    'any local deletion failure returns unknown after attempting all stores',
    () async {
      final localStore = _FaultingLocalResetStore(
        preferencesCleared: false,
        secureStorageThrows: true,
        filesCleared: false,
      );

      final result = await AppResetService.clearLocalData(
        localStore: localStore,
      );

      expect(result, WipeResult.unknown);
      expect(
        localStore.operations,
        ['preferences', 'database', 'files', 'secureStorage'],
        reason:
            'Deletion is best-effort across every local store before retry, '
            'and the credential store is always last: the PIN is what keeps '
            'the other boundaries unreadable if one of them fails.',
      );
    },
  );

  test('all acknowledged local deletions return completed', () async {
    final localStore = _FaultingLocalResetStore();

    final result = await AppResetService.clearLocalData(localStore: localStore);

    expect(result, WipeResult.completed);
    expect(localStore.operations, [
      'preferences',
      'database',
      'files',
      'secureStorage',
    ]);
  });

  test('the PIN outlives every boundary that failed to delete', () async {
    // The regression this pins: secure storage used to be cleared second, so a
    // database or file-system failure left real user data on disk with the PIN
    // -- the only thing guarding it -- already gone.
    final localStore = _FaultingLocalResetStore(
      preferencesCleared: false,
      filesCleared: false,
    );

    final result = await AppResetService.clearLocalData(localStore: localStore);

    expect(result, WipeResult.unknown);
    expect(
      localStore.operations.last,
      'secureStorage',
      reason:
          'Every failed boundary above must still be covered by the PIN, so '
          'the credential store may only be cleared once they are done.',
    );
    expect(
      localStore.operations.indexOf('secureStorage'),
      greaterThan(localStore.operations.indexOf('database')),
      reason: 'A surviving database must never outlive its PIN.',
    );
  });
}
