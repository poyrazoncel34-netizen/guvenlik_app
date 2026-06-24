import 'package:flutter/services.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory [SecureStorage] fake for unit tests. Records write/delete counts
/// and can be made to fail reads/writes (Keystore-failure simulation) or to
/// silently drop writes (lost-write / interrupted-migration simulation).
class FakeSecureStorage extends SecureStorage {
  final Map<String, String> store = <String, String>{};

  bool failReads = false;
  bool failWrites = false;

  /// When true, [write] is a no-op (value never persisted) — simulates a write
  /// that "succeeded" but did not land, so verify-before-delete must catch it.
  bool dropWrites = false;

  int writeCount = 0;
  int deleteCount = 0;

  @override
  Future<void> write({required String key, required String value}) async {
    writeCount++;
    if (failWrites) {
      throw PlatformException(code: 'write_fail');
    }
    if (dropWrites) {
      return;
    }
    store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    if (failReads) {
      throw PlatformException(code: 'read_fail');
    }
    return store[key];
  }

  @override
  Future<void> delete({required String key}) async {
    deleteCount++;
    store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    store.clear();
  }
}

/// [LocalDatabaseService] backed by an in-memory sqflite-ffi database with the
/// production `contacts` schema. Lets tests seed plaintext rows and assert the
/// migration empties them.
class FakeLocalDatabaseService extends LocalDatabaseService {
  Database? _db;

  @override
  Future<Database> get database async {
    return _db ??= await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        // Fresh in-memory DB per fake; defeats the ffi factory's :memory: cache
        // so seeded rows never leak across tests.
        singleInstance: false,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE contacts(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              phone TEXT NOT NULL UNIQUE,
              is_primary INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
  }

  @override
  Future<void> deleteDatabaseFile() async {
    // No real file in tests; just drop the in-memory handle.
    await _db?.close();
    _db = null;
  }

  Future<void> seedContact({
    required String name,
    required String phone,
    bool isPrimary = false,
    String? createdAt,
  }) async {
    final db = await database;
    await db.insert('contacts', {
      'name': name,
      'phone': phone,
      'is_primary': isPrimary ? 1 : 0,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    });
  }

  Future<int> contactRowCount() async {
    final db = await database;
    final rows = await db.query('contacts');
    return rows.length;
  }
}

/// Initialise sqflite-ffi for host-side tests. Safe to call repeatedly.
void initContactServiceTestFfi() {
  sqfliteFfiInit();
}
