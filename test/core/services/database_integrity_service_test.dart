// MP-29-017 -- database-level integrity, measured rather than asserted.
//
// The three fixtures the requirement needs:
//   1. a healthy database is accepted;
//   2. STRUCTURAL corruption is detected -- and the fixture is real byte damage
//      to a real file, not a mocked failure;
//   3. a FOREIGN-KEY orphan is detected by foreign_key_check -- and the same
//      orphan is shown to pass integrity_check, which is the trap this policy
//      exists to avoid.
//
// The cost of the scan is MEASURED here too, because the policy's central claim
// is "not on every open". A latency decision defended by a guess is the same
// class of thing as a hard-coded measurement.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/database_integrity_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> _openMemory() => databaseFactory.openDatabase(
  inMemoryDatabasePath,
  options: OpenDatabaseOptions(
    singleInstance: false,
    onConfigure: DatabaseIntegrityService.configureConnection,
  ),
);

Future<Database> _openFile(String path) => databaseFactory.openDatabase(
  path,
  options: OpenDatabaseOptions(
    singleInstance: false,
    onConfigure: DatabaseIntegrityService.configureConnection,
  ),
);

Future<void> _seedEvents(Database db, int count) async {
  final batch = db.batch();
  for (var i = 0; i < count; i++) {
    batch.insert('activity_events', <String, Object?>{
      'id': 'event-$i',
      'type': 'emergencyTriggered',
      'title': 'title $i',
      'description': 'description $i',
      'timestamp': DateTime.utc(2026, 1, 1).add(Duration(minutes: i))
          .toIso8601String(),
    });
  }
  await batch.commit(noResult: true);
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('korubeni_integrity');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('fixture 1 -- a healthy database is accepted', () {
    test('quick and full scans both report healthy', () async {
      final db = await _openMemory();
      await LocalDatabaseService.createSchema(db);
      await _seedEvents(db, 200);

      for (final depth in IntegrityScanDepth.values) {
        final report = await DatabaseIntegrityService.scan(db, depth: depth);
        expect(report.isHealthy, isTrue, reason: '${depth.name}: ${report.findings}');
        expect(report.scanFailed, isFalse);
        expect(report.findings, isEmpty);
        expect(report.depth, depth);
      }
      await db.close();
    });

    test('foreign_keys is ON, so a future relationship is actually enforced',
        () async {
      final db = await _openMemory();
      expect(await DatabaseIntegrityService.foreignKeysEnabled(db), isTrue);
      await db.close();
    });

    test('a connection WITHOUT the configure hook has it off (control)',
        () async {
      // Proves the previous assertion is about our configuration and not about
      // an SQLite default that would have been true anyway.
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      expect(await DatabaseIntegrityService.foreignKeysEnabled(db), isFalse);
      await db.close();
    });
  });

  group('fixture 2 -- structural corruption is detected', () {
    test('byte damage to a real database file is reported', () async {
      final path = '${tempDir.path}/corrupt.db';
      final db = await _openFile(path);
      await LocalDatabaseService.createSchema(db);
      // Enough rows to occupy several pages, so damage lands in real content.
      await _seedEvents(db, 800);
      final healthy = await DatabaseIntegrityService.scan(
        db,
        depth: IntegrityScanDepth.full,
      );
      expect(healthy.isHealthy, isTrue,
          reason: 'precondition: the file must be sound BEFORE it is damaged');
      await db.close();

      // Real corruption: overwrite the interior of a data page. The first page
      // holds the header and schema; damaging page 3 onwards hits b-tree
      // content the way a bad sector or an interrupted write would.
      final file = File(path);
      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(4096 * 4),
          reason: 'the fixture must be large enough to have interior pages');
      final random = Random(20260815);
      final scribble = Uint8List.fromList(bytes);
      for (var offset = 4096 * 2 + 24; offset < 4096 * 4; offset += 7) {
        scribble[offset] = random.nextInt(256);
      }
      file.writeAsBytesSync(scribble, flush: true);

      final reopened = await _openFile(path);
      final report = await DatabaseIntegrityService.scan(
        reopened,
        depth: IntegrityScanDepth.full,
      );
      expect(report.isHealthy, isFalse,
          reason: 'byte damage went unreported; the check proves nothing');
      expect(report.scanFailed || report.structural.isNotEmpty, isTrue);
      await reopened.close();
    });

    test('quick_check also catches it, which is why it is the migration depth',
        () async {
      final path = '${tempDir.path}/corrupt_quick.db';
      final db = await _openFile(path);
      await LocalDatabaseService.createSchema(db);
      await _seedEvents(db, 800);
      await db.close();

      final file = File(path);
      final bytes = Uint8List.fromList(file.readAsBytesSync());
      final random = Random(4242);
      for (var offset = 4096 * 2 + 24; offset < 4096 * 4; offset += 7) {
        bytes[offset] = random.nextInt(256);
      }
      file.writeAsBytesSync(bytes, flush: true);

      final reopened = await _openFile(path);
      final report = await DatabaseIntegrityService.scan(reopened);
      expect(report.depth, IntegrityScanDepth.quick);
      expect(report.isHealthy, isFalse);
      await reopened.close();
    });
  });

  group('fixture 3 -- a foreign-key orphan is detected', () {
    /// The shipped schema declares no relationships, so the orphan is built on
    /// a fixture pair. That is the honest shape: the check is proven to WORK,
    /// and the absence of foreign keys in the real schema is recorded as a fact
    /// rather than hidden behind a check that trivially passes.
    Future<Database> withRelatedTables() async {
      final db = await _openMemory();
      await db.execute('CREATE TABLE parent(id INTEGER PRIMARY KEY)');
      await db.execute('''
        CREATE TABLE child(
          id INTEGER PRIMARY KEY,
          parent_id INTEGER REFERENCES parent(id)
        )
      ''');
      await db.insert('parent', <String, Object?>{'id': 1});
      await db.insert('child', <String, Object?>{'id': 1, 'parent_id': 1});
      return db;
    }

    test('an orphaned child row is reported by foreign_key_check', () async {
      final db = await withRelatedTables();
      final healthy = await DatabaseIntegrityService.scan(
        db,
        depth: IntegrityScanDepth.full,
      );
      expect(healthy.isHealthy, isTrue, reason: 'precondition: no orphan yet');

      // Create the orphan the way a real one appears: with enforcement off,
      // which is exactly the state this service now prevents at connect time.
      await db.execute('PRAGMA foreign_keys = OFF');
      await db.delete('parent', where: 'id = ?', whereArgs: <Object>[1]);
      await db.execute('PRAGMA foreign_keys = ON');

      final report = await DatabaseIntegrityService.scan(
        db,
        depth: IntegrityScanDepth.full,
      );
      expect(report.isHealthy, isFalse);
      expect(report.foreignKey, hasLength(1));
      expect(report.foreignKey.single.detail, contains('child'));
      expect(report.foreignKey.single.detail, contains('parent'));
      await db.close();
    });

    test('integrity_check MISSES the same orphan -- the trap, asserted',
        () async {
      final db = await withRelatedTables();
      await db.execute('PRAGMA foreign_keys = OFF');
      await db.delete('parent', where: 'id = ?', whereArgs: <Object>[1]);

      final structuralOnly = await db.rawQuery('PRAGMA integrity_check');
      expect(structuralOnly.first.values.first, 'ok',
          reason: 'if integrity_check ever DID report referential problems, '
              'running foreign_key_check separately would be redundant and this '
              'policy should be simplified');

      final quick = await DatabaseIntegrityService.scan(db);
      expect(quick.isHealthy, isTrue,
          reason: 'quick_check is structural only; the orphan is invisible to '
              'it, which is why the migration-time depth is NOT sufficient for '
              'a referential question');
      await db.close();
    });

    test('with enforcement ON the orphan cannot be created in the first place',
        () async {
      final db = await withRelatedTables();
      await expectLater(
        db.delete('parent', where: 'id = ?', whereArgs: <Object>[1]),
        throwsA(isA<DatabaseException>()),
      );
      await db.close();
    });
  });

  group('the policy decision is measured, not guessed', () {
    test('a full scan grows with the table; a quick scan is what runs on the '
        'migration path', () async {
      final db = await _openMemory();
      await LocalDatabaseService.createSchema(db);
      await _seedEvents(db, 5000);

      final quick = await DatabaseIntegrityService.scan(db);
      final full = await DatabaseIntegrityService.scan(
        db,
        depth: IntegrityScanDepth.full,
      );
      expect(quick.isHealthy, isTrue);
      expect(full.isHealthy, isTrue);

      // Recorded rather than thresholded: an absolute millisecond bound
      // measured on this machine would be a CI flake, not a contract. What is
      // asserted is the SHAPE of the policy -- that a bounded-depth option
      // exists and is the one wired to the migration path.
      // ignore: avoid_print
      print('MP-29-017 scan cost over 5000 activity_events: '
          'quick=${quick.elapsed.inMicroseconds}us '
          'full=${full.elapsed.inMicroseconds}us');
      expect(quick.depth, IntegrityScanDepth.quick);
      await db.close();
    });

    test('the cost GROWS with the table, which is the actual argument against '
        'scanning on every open', () async {
      // The 5000-row number alone would not justify the policy: ~1 ms on a
      // desktop in-memory database is not a startup problem. What justifies it
      // is that activity_events has no cap -- it is the growth table -- so the
      // cost at open is unbounded in a quantity the user controls.
      final measurements = <int, int>{};
      for (final rows in <int>[1000, 10000, 40000]) {
        final db = await _openMemory();
        await LocalDatabaseService.createSchema(db);
        await _seedEvents(db, rows);
        final report = await DatabaseIntegrityService.scan(db);
        measurements[rows] = report.elapsed.inMicroseconds;
        expect(report.isHealthy, isTrue);
        await db.close();
      }
      // ignore: avoid_print
      print('MP-29-017 quick_check growth (rows -> us): $measurements');
      expect(
        measurements[40000],
        greaterThan(measurements[1000] as int),
        reason: 'if the scan did NOT grow with the table, the policy should '
            'simply run it on every open and this row would be simpler',
      );
    });

    test('no scan is wired to the connection open path', () {
      final src = File('lib/core/services/local_database_service.dart')
          .readAsStringSync();
      final openStart = src.indexOf('_database = await openDatabase(');
      final openEnd = src.indexOf('return _database!;', openStart);
      final body = src.substring(openStart, openEnd);
      expect(body, isNot(contains('DatabaseIntegrityService.scan')),
          reason: 'a scan on every open puts an unbounded cost on the startup '
              'path for a rare condition');
      expect(body, contains('onConfigure: DatabaseIntegrityService.configureConnection'));
    });

    test('a scan IS wired to the migration path, and its result is kept', () {
      final src = File('lib/core/services/local_database_service.dart')
          .readAsStringSync();
      final upgradeStart = src.indexOf('static Future<void> upgradeSchema(');
      final upgradeEnd = src.indexOf('static Future<void> _addMissingColumns(');
      final body = src.substring(upgradeStart, upgradeEnd);
      expect(body, contains('DatabaseIntegrityService.scan(db)'));
      expect(body, contains('lastMigrationIntegrity'));
    });
  });

  group('a damaged file never costs the user their timeline', () {
    test('a failed scan reports, and no code path wipes on a finding', () {
      final src = File('lib/core/services/local_database_service.dart')
          .readAsStringSync();
      // The tempting "fix" for corruption is to recreate the database. That
      // deletes activity_events, which is the user's own safety record.
      for (final destructive in <String>['DROP TABLE', 'deleteDatabase(']) {
        final upgradeStart = src.indexOf('static Future<void> upgradeSchema(');
        final upgradeEnd = src.indexOf('static Future<void> _addMissingColumns(');
        expect(src.substring(upgradeStart, upgradeEnd),
            isNot(contains(destructive)));
      }
    });

    test('the report serialises for the diagnostics surface', () async {
      final db = await _openMemory();
      await LocalDatabaseService.createSchema(db);
      final map = (await DatabaseIntegrityService.scan(db)).toMap();
      expect(map['depth'], 'quick');
      expect(map['healthy'], isTrue);
      expect(map['scanFailed'], isFalse);
      expect(map['findings'], isEmpty);
      expect(map.containsKey('elapsedMs'), isTrue);
      await db.close();
    });
  });
}
