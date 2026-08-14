import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_integrity_service.dart';

class LocalDatabaseService {
  LocalDatabaseService();

  static const String databaseName = 'korubeni.db';

  /// v3 added `app_version` / `environment` to `crash_logs` so a user-submitted
  /// diagnostic export is self-describing.
  ///
  /// Bumping this without extending [upgradeSchema] ships a column that exists
  /// only on fresh installs: upgrading users keep the old table and every
  /// insert naming the new column fails. That is precisely the bug the previous
  /// `oldVersion < 1` guard hid, because sqflite user_version starts at 1 and
  /// the branch could never run.
  static const int databaseVersion = 3;

  Database? _database;

  Future<void> initialize() async {
    await database;
  }

  Future<Database> get database async {
    final db = _database;
    if (db != null) {
      return db;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$databaseName';
    _database = await openDatabase(
      path,
      version: databaseVersion,
      // Per-connection, constant cost. SQLite defaults foreign_keys OFF, so a
      // relationship declared later would be silently unenforced -- the same
      // shape of dead safeguard as the `oldVersion < 1` branch below.
      onConfigure: DatabaseIntegrityService.configureConnection,
      onCreate: (db, version) => createSchema(db),
      onUpgrade: upgradeSchema,
    );
    return _database!;
  }

  /// Full current schema. Public so migration behaviour is testable against an
  /// in-memory sqflite-ffi database rather than only on a real device.
  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL UNIQUE,
        is_primary INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE activity_events(
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE crash_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL,
        error TEXT NOT NULL,
        stack TEXT,
        created_at TEXT NOT NULL,
        app_version TEXT,
        environment TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE app_settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  /// Additive-only migration. Every step is `ADD COLUMN` or `CREATE TABLE`, so
  /// no upgrade path can drop a row: `activity_events` is the user's own safety
  /// timeline and losing it silently would be worse than any diagnostic gain.
  static Future<void> upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Safety net for a partially-created database: create anything missing
    // before attempting to alter it.
    final tables = await db.query(
      'sqlite_master',
      columns: <String>['name'],
      where: 'type = ?',
      whereArgs: <Object>['table'],
    );
    final tableNames = tables
        .map((row) => row['name'] as String?)
        .whereType<String>()
        .toSet();
    if (!tableNames.contains('crash_logs')) {
      await createSchema(db);
      return;
    }

    if (oldVersion < 3) {
      await _addMissingColumns(db, 'crash_logs', const <String, String>{
        'app_version': 'TEXT',
        'environment': 'TEXT',
      });
    }

    // A migration is the one moment the app itself may have damaged the file,
    // it happens once per version, and the user is already waiting. Deliberately
    // the QUICK check: the full index cross-check is unbounded in the size of
    // activity_events, and is reserved for the diagnostics path where the user
    // asked for it. See DatabaseIntegrityService for the whole policy, and
    // lastMigrationIntegrity for what a failure here does (report, never wipe:
    // activity_events is real user data).
    lastMigrationIntegrity = await DatabaseIntegrityService.scan(db);
  }

  /// The report from the most recent migration-time scan, or null when no
  /// migration ran in this process. Exposed rather than logged-and-forgotten so
  /// the diagnostics screen can surface a real finding, and so a test can prove
  /// the scan actually ran.
  static IntegrityReport? lastMigrationIntegrity;

  /// Idempotent `ADD COLUMN`. Re-running a migration must not throw: a user who
  /// hits a half-applied upgrade should end up with a working database, not a
  /// permanently unopenable one.
  static Future<void> _addMissingColumns(
    Database db,
    String table,
    Map<String, String> columns,
  ) async {
    final existing = await db.rawQuery('PRAGMA table_info($table)');
    final existingNames = existing
        .map((row) => row['name'] as String?)
        .whereType<String>()
        .toSet();
    for (final entry in columns.entries) {
      if (existingNames.contains(entry.key)) continue;
      await db.execute('ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}');
    }
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('contacts');
      await txn.delete('activity_events');
      await txn.delete('crash_logs');
      await txn.delete('app_settings');
    });
  }

  Future<void> deleteDatabaseFile() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$databaseName');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
