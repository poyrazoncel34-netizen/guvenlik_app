import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/app_reset_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KVKK Md.7 (silme): "Verilerimi Sil" must also wipe the NATIVE
/// korubeni_emergency SharedPreferences, which holds the primary contact
/// number (KEY_CHECK_IN_PRIMARY_NUMBER / KEY_COUNTDOWN_PRIMARY_NUMBER). The
/// Dart-side prefs.clear() only touches the Flutter-managed store, leaving the
/// native number behind after a native fire. clearLocalData() must invoke the
/// native clearEmergencyPrefs channel method.
class _FakeSecureStorage extends SecureStorage {
  @override
  Future<void> deleteAll() async {}
}

class _FakeLocalDatabaseService extends LocalDatabaseService {
  @override
  Future<void> deleteDatabaseFile() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.poyrazoncel.korubeni/emergency_platform');
  final invoked = <String>[];

  setUp(() async {
    invoked.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{'seed': 1});
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(_FakeSecureStorage());
    serviceLocator.registerSingleton<LocalDatabaseService>(
      _FakeLocalDatabaseService(),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          invoked.add(call.method);
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await serviceLocator.reset();
  });

  test(
    'clearLocalData invokes native clearEmergencyPrefs (KVKK Md.7)',
    () async {
      await AppResetService.clearLocalData();
      expect(
        invoked,
        contains('clearEmergencyPrefs'),
        reason: 'reset must wipe the native emergency prefs (primary number)',
      );
    },
  );
}
