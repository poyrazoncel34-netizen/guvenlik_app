import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/app_reset_service.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_service_test_support.dart';

/// KVKK Md.7 (§10.6): "Delete my data" must also drop the in-memory warm cache,
/// otherwise the emergency path could keep serving a contact after deletion.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();

  const channel = MethodChannel('com.poyrazoncel.korubeni/emergency_platform');

  late FakeSecureStorage secure;
  late FakeLocalDatabaseService db;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    secure = FakeSecureStorage();
    db = FakeLocalDatabaseService();
    serviceLocator.registerSingleton<SecureStorage>(secure);
    serviceLocator.registerSingleton<LocalDatabaseService>(db);
    ContactService.resetCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'wipeEmergencySessions') {
            return <String, Object?>{'type': 'completed'};
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    ContactService.resetCache();
    await serviceLocator.reset();
  });

  test(
    'clearLocalData invalidates the warm cache (read returns empty)',
    () async {
      secure.store[SecureStorageKeys.emergencyContactsV1] = jsonEncode({
        'version': 1,
        'contacts': [
          {'name': 'Ada', 'phone': '+905551112233', 'isPrimary': true},
        ],
      });
      final warmed = await ContactService.getContactRecords();
      expect(warmed, hasLength(1));

      await AppResetService.clearLocalData();

      final afterReset = await ContactService.getContactRecords();
      expect(
        afterReset,
        isEmpty,
        reason: 'cache cleared and secure store wiped on KVKK delete',
      );
    },
  );

  test('app_reset_service wires ContactService.resetCache()', () {
    final src = File(
      'lib/core/services/app_reset_service.dart',
    ).readAsStringSync();
    expect(src.contains('ContactService.resetCache()'), isTrue);
  });
}
