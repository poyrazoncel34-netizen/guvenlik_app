// A-014: the profile e-mail had no input field, yet it was stored and exported.
//
// Builds before 2026-04-16 DID have an e-mail field, so a value typed there can
// still be sitting in SharedPreferences on an upgraded device. These cases run
// the real provider and the real KVKK export against that state: the old value
// must be deleted by the NORMAL STARTUP PATH (no screen needs to open), a failed
// deletion must be retried on the next launch, and the export must carry no
// e-mail at all -- not an empty one, not the stale one.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/best_effort_startup.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/profile_email_cleanup_service.dart';
import 'package:guvenlik_app/core/services/startup_best_effort_services.dart';
import 'package:guvenlik_app/core/services/user_data_export_service.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'contact_service_test_support.dart';

/// The raw key old builds wrote. Deliberately a literal, not a constant from
/// lib: the test must check the key that is really on users' devices.
const String kLegacyEmailKey = 'profile_email';
const String kLegacyEmail = 'eski.adres@ornek.com';

/// Production schema on a fresh in-memory database per test.
class _SchemaDatabase extends LocalDatabaseService {
  Database? _db;

  @override
  Future<Database> get database async =>
      _db ??= await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: LocalDatabaseService.databaseVersion,
          singleInstance: false,
          onCreate: (db, _) => LocalDatabaseService.createSchema(db),
        ),
      );
}

Iterable<String> allKeys(Object? node) sync* {
  if (node is Map) {
    for (final entry in node.entries) {
      yield entry.key.toString();
      yield* allKeys(entry.value);
    }
  } else if (node is List) {
    for (final value in node) {
      yield* allKeys(value);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kLegacyEmailKey: kLegacyEmail,
      'profile_name': 'Ali',
    });
    await serviceLocator.reset();
    ContactService.resetCache();
    serviceLocator.registerSingleton<SecureStorage>(FakeSecureStorage());
    serviceLocator.registerSingleton<LocalDatabaseService>(_SchemaDatabase());
    serviceLocator.registerSingleton<ConsentManager>(ConsentManager());
  });

  tearDown(() async {
    ContactService.resetCache();
    await serviceLocator.reset();
  });

  test(
    'the startup best-effort list deletes the e-mail with no screen opened',
    () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kLegacyEmailKey), kLegacyEmail);

      // The exact list main() passes to initializeBestEffortServices, run by
      // the real helper. Every other entry may fail here (no plugins in a
      // unit test); the helper isolates them, and so must the cleanup.
      await initializeBestEffortServices(
        buildStartupBestEffortServices(isWeb: false),
        timeout: const Duration(seconds: 2),
      );

      expect(
        prefs.containsKey(kLegacyEmailKey),
        isFalse,
        reason:
            'left in place it survives every update, unreadable and '
            'unexportable, until a full data wipe',
      );
      expect(prefs.getString('profile_name'), 'Ali');
    },
  );

  test('the web startup list runs the cleanup too', () {
    expect(
      buildStartupBestEffortServices(isWeb: true),
      contains(ProfileEmailCleanupService.purgeIfNeeded),
    );
  });

  test('a failed deletion keeps the key and the next launch retries', () async {
    final store = _FlakyStore(failuresLeft: 1);

    expect(await ProfileEmailCleanupService.purgeIfNeeded(store: store), isFalse);
    expect(store.keys, contains(kLegacyEmailKey), reason: 'launch 1 failed');

    expect(await ProfileEmailCleanupService.purgeIfNeeded(store: store), isTrue);
    expect(store.keys, isNot(contains(kLegacyEmailKey)), reason: 'launch 2');
  });

  test('a refused deletion (remove -> false) is reported, not assumed', () async {
    final store = _FlakyStore(refusalsLeft: 1);

    expect(await ProfileEmailCleanupService.purgeIfNeeded(store: store), isFalse);
    expect(store.keys, contains(kLegacyEmailKey));
    expect(await ProfileEmailCleanupService.purgeIfNeeded(store: store), isTrue);
    expect(store.keys, isEmpty);
  });

  test('startup without a legacy value does not create one', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'profile_name': 'Ali',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(await ProfileEmailCleanupService.purgeIfNeeded(), isTrue);

    expect(prefs.containsKey(kLegacyEmailKey), isFalse);
    expect(prefs.getString('profile_name'), 'Ali');
  });

  test('the KVKK export carries no e-mail field at all', () async {
    // Export BEFORE any profile load, so the stale value is still on disk:
    // the export must not pick it up either.
    final export = await UserDataExportService.buildExportData();

    expect(
      export['profile'],
      <String, dynamic>{'name': 'Ali'},
      reason: 'the profile section is the name, and only the name',
    );
    expect(
      allKeys(export),
      isNot(contains('email')),
      reason: 'an always-empty `email` entry was a data field in no inventory',
    );
    expect(jsonEncode(export), isNot(contains(kLegacyEmail)));
  });
}

class _FlakyStore implements ProfileEmailCleanupStore {
  _FlakyStore({this.failuresLeft = 0, this.refusalsLeft = 0});

  int failuresLeft;
  int refusalsLeft;
  final Set<String> keys = <String>{kLegacyEmailKey};

  @override
  Future<bool> contains(String key) async => keys.contains(key);

  @override
  Future<bool> remove(String key) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw Exception('disk full');
    }
    if (refusalsLeft > 0) {
      refusalsLeft--;
      return false;
    }
    return keys.remove(key);
  }
}
