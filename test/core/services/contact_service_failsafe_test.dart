import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_service_test_support.dart';

/// Fail-safe (§10.2b / AR-2): a secure-storage read failure must NEVER throw
/// to the emergency path and must NEVER silently delete the contact. It falls
/// back to last-good cache, then a read-only DB copy, then an empty list.
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

  test(
    'read error returns last-good cache without throwing or deleting',
    () async {
      secure.store[SecureStorageKeys.emergencyContactsV1] = jsonEncode({
        'version': 1,
        'contacts': [
          {'name': 'Ada', 'phone': '+905551112233', 'isPrimary': true},
        ],
      });
      // Warm the cache from a healthy read first.
      final warmed = await ContactService.getContactRecords();
      expect(warmed, hasLength(1));

      // Now the Keystore starts failing reads.
      secure.failReads = true;
      final deletesBefore = secure.deleteCount;

      final read = await ContactService.getContactRecords();
      expect(read.map((c) => c.phone), [
        '+905551112233',
      ], reason: 'serves last-good cache on read failure');
      expect(
        secure.deleteCount,
        deletesBefore,
        reason: 'never deletes the contact on a read error',
      );
    },
  );

  test('read error with cold cache falls back to read-only DB copy', () async {
    await db.seedContact(name: 'Ada', phone: '+905551112233', isPrimary: true);
    secure.failReads = true;

    final read = await ContactService.getContactRecords();

    expect(read.map((c) => c.phone), ['+905551112233']);
    // Must not migrate/clear on a read-error path.
    expect(await db.contactRowCount(), 1);
    expect(secure.deleteCount, 0);
  });

  test(
    'read error with no data anywhere returns empty list (no throw)',
    () async {
      secure.failReads = true;

      final read = await ContactService.getContactRecords();

      expect(read, isEmpty);
      expect(secure.deleteCount, 0);
    },
  );

  test('corrupt canonical value is never auto-deleted', () async {
    secure.store[SecureStorageKeys.emergencyContactsV1] = 'not-json-@@@';
    final deletesBefore = secure.deleteCount;

    final read = await ContactService.getContactRecords();

    expect(read, isEmpty, reason: 'falls through to empty fail-safe');
    expect(
      secure.deleteCount,
      deletesBefore,
      reason: 'corrupt data is preserved, never silently wiped',
    );
  });
}
