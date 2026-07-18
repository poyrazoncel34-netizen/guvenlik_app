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
      final result = await AppResetService.clearLocalData();
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
}
