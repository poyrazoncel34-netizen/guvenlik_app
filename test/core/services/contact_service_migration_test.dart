import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_service_test_support.dart';

/// Migration (§10.3): DB plaintext -> canonical secure storage, idempotent,
/// kill-safe, verify-before-delete. Absolute constraint: a configured contact
/// must NEVER be lost at any interruption point.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();

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
  });

  tearDown(() async {
    ContactService.resetCache();
    await serviceLocator.reset();
  });

  String canonicalEnvelope(List<Map<String, Object>> contacts) =>
      jsonEncode({'version': 1, 'contacts': contacts});

  test('migrates plaintext DB rows into canonical secure storage', () async {
    await db.seedContact(name: 'Ada', phone: '+905551112233', isPrimary: true);
    await db.seedContact(name: 'Bora', phone: '+905554445566');

    final read = await ContactService.getContactRecords();

    expect(
      read.map((c) => c.phone),
      containsAll(['+905551112233', '+905554445566']),
    );
    expect(read.firstWhere((c) => c.isPrimary).phone, '+905551112233');
    // Canonical populated, DB rows emptied.
    expect(secure.store[SecureStorageKeys.emergencyContactsV1], isNotNull);
    expect(await db.contactRowCount(), 0);
  });

  test('migration is idempotent: second pass is a no-op', () async {
    await db.seedContact(name: 'Ada', phone: '+905551112233', isPrimary: true);

    final first = await ContactService.getContactRecords();
    ContactService.resetCache();
    final second = await ContactService.getContactRecords();

    expect(first.map((c) => c.phone), second.map((c) => c.phone));
    expect(second, hasLength(1));
    expect(await db.contactRowCount(), 0);
  });

  test(
    'kill-safe recovery: canonical written but DB rows linger, flag set',
    () async {
      // Simulate a crash AFTER canonical write+verify but BEFORE DB clear.
      secure.store[SecureStorageKeys.emergencyContactsV1] = canonicalEnvelope([
        {'name': 'Ada', 'phone': '+905551112233', 'isPrimary': true},
      ]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefContactsSecureMigratedV1, true);
      await db.seedContact(
        name: 'Ada',
        phone: '+905551112233',
        isPrimary: true,
      );

      final read = await ContactService.getContactRecords();

      // Contact never lost; lingering DB rows reconciled (cleared).
      expect(read, hasLength(1));
      expect(read.first.phone, '+905551112233');
      expect(await db.contactRowCount(), 0);
    },
  );

  test(
    'verify-before-delete: lost write keeps DB rows intact (no loss)',
    () async {
      await db.seedContact(
        name: 'Ada',
        phone: '+905551112233',
        isPrimary: true,
      );
      // Writes silently fail to persist -> read-back verify must fail.
      secure.dropWrites = true;

      final read = await ContactService.getContactRecords();

      // DB rows must remain as the surviving source; data still readable.
      expect(await db.contactRowCount(), 1);
      expect(read.map((c) => c.phone), ['+905551112233']);
      // Canonical must NOT be left half-written.
      expect(secure.store[SecureStorageKeys.emergencyContactsV1], isNull);
    },
  );

  test('legacy secure/prefs are migrated then cleared', () async {
    // Old format: contactsData JSON list + emergencyContactPhone/Name.
    secure.store[SecureStorageKeys.contactsData] = jsonEncode([
      {'name': 'Ada', 'phone': '+905551112233'},
    ]);
    secure.store[SecureStorageKeys.emergencyContactPhone] = '+905551112233';
    secure.store[SecureStorageKeys.emergencyContactName] = 'Ada';

    final read = await ContactService.getContactRecords();

    expect(read.map((c) => c.phone), ['+905551112233']);
    expect(read.first.isPrimary, isTrue);
    expect(secure.store[SecureStorageKeys.emergencyContactsV1], isNotNull);
    // Legacy keys cleared after verified migration.
    expect(secure.store[SecureStorageKeys.contactsData], isNull);
    expect(secure.store[SecureStorageKeys.emergencyContactPhone], isNull);
  });
}
