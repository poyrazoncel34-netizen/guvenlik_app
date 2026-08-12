// Regression cover for the local schema migration path.
//
// Why this exists: `_onUpgrade` used to read
//   if (oldVersion < 1) { await _onCreate(db, newVersion); }
// sqflite's user_version starts at 1, so that branch could never execute. The
// migration hook was dead code that LOOKED like a migration system. Any column
// added later would have existed only on fresh installs, and every insert
// naming it would have failed for upgrading users -- a defect invisible on a
// freshly wiped emulator and visible to every real user who had the app before.
//
// These tests drive the real createSchema/upgradeSchema against sqflite-ffi.

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The crash_logs table exactly as shipped at databaseVersion 2, i.e. before
/// app_version/environment existed. Hardcoded on purpose: it represents a build
/// already installed on users' phones and must not track future edits to
/// createSchema.
const String _v2CrashLogs = '''
  CREATE TABLE crash_logs(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT NOT NULL,
    error TEXT NOT NULL,
    stack TEXT,
    created_at TEXT NOT NULL
  )
''';

const String _v2ActivityEvents = '''
  CREATE TABLE activity_events(
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    timestamp TEXT NOT NULL
  )
''';

Future<Set<String>> _columns(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.map((r) => r['name'] as String).toSet();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> openV2Database() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute(_v2CrashLogs);
    await db.execute(_v2ActivityEvents);
    return db;
  }

  test('fresh install gets the current crash_logs schema', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(db.close);

    await LocalDatabaseService.createSchema(db);

    final columns = await _columns(db, 'crash_logs');
    expect(columns, containsAll(<String>['app_version', 'environment']));
  });

  test(
    'upgrading a v2 database adds the diagnostic columns instead of silently '
    'leaving the old table in place',
    () async {
      final db = await openV2Database();
      addTearDown(db.close);

      expect(
        await _columns(db, 'crash_logs'),
        isNot(contains('app_version')),
        reason: 'precondition: v2 has no app_version column',
      );

      await LocalDatabaseService.upgradeSchema(db, 2, 3);

      expect(
        await _columns(db, 'crash_logs'),
        containsAll(<String>['app_version', 'environment']),
      );

      // The column must be usable, not merely present.
      await db.insert('crash_logs', <String, Object?>{
        'source': 'runtime',
        'error': 'TEST_CODE',
        'created_at': DateTime.now().toIso8601String(),
        'app_version': '1.0.0+1',
        'environment': 'production',
      });
      final rows = await db.query('crash_logs');
      expect(rows.single['app_version'], '1.0.0+1');
      expect(rows.single['environment'], 'production');
    },
  );

  test('migration never drops the user safety timeline', () async {
    final db = await openV2Database();
    addTearDown(db.close);

    await db.insert('activity_events', <String, Object?>{
      'id': 'evt-1',
      'type': 'checkin',
      'title': 'Kontrol noktasi',
      'description': 'kullanici kaydi',
      'timestamp': DateTime.now().toIso8601String(),
    });

    await LocalDatabaseService.upgradeSchema(db, 2, 3);

    final rows = await db.query('activity_events');
    expect(
      rows.single['id'],
      'evt-1',
      reason:
          'activity_events is the user\'s own safety timeline; an upgrade that '
          'recreates rather than alters would erase it silently.',
    );
  });

  test('re-running the same migration is safe', () async {
    final db = await openV2Database();
    addTearDown(db.close);

    await LocalDatabaseService.upgradeSchema(db, 2, 3);
    // A half-applied upgrade that is retried must not leave the database
    // permanently unopenable.
    await LocalDatabaseService.upgradeSchema(db, 2, 3);

    expect(
      await _columns(db, 'crash_logs'),
      containsAll(<String>['app_version', 'environment']),
    );
  });

  test('a database missing crash_logs entirely is repaired, not left broken', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(db.close);

    await LocalDatabaseService.upgradeSchema(db, 2, 3);

    expect(await _columns(db, 'crash_logs'), contains('app_version'));
    expect(await _columns(db, 'contacts'), contains('phone'));
  });

  test('declared databaseVersion matches the migrations implemented', () {
    // Guard against the exact failure mode this file documents: bumping the
    // version without extending upgradeSchema.
    expect(
      LocalDatabaseService.databaseVersion,
      3,
      reason:
          'If you raise databaseVersion, add the matching branch to '
          'upgradeSchema and a case here first.',
    );
  });
}
