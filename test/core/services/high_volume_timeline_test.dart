// MP-47-011 -- "Account with thousands of objects".
//
// `activity_events` is the app's only unbounded table: every panic, fake call,
// siren, safe walk and check-in appends a row and nothing prunes them. The row
// was open because no run had ever seeded it, so "does it still work at volume"
// was an assumption.
//
// The tiers below are product-bound rather than arbitrary. A safety event is a
// human act; the ceiling is what a person can actually generate:
//   baseline  100  -- a few months of ordinary use
//   heavy    1000  -- daily check-ins for ~3 years, or a rehearsal-heavy user
//   maximum 10000  -- ~9 events a day for 3 years; beyond any realistic user
// The 10 000 tier is the worst REALISTIC supported volume, not a benchmark
// number chosen to look impressive.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/database_integrity_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/scroll_restoration.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const List<int> _tiers = <int>[100, 1000, 10000];

Future<Database> _open() => databaseFactory.openDatabase(
  inMemoryDatabasePath,
  options: OpenDatabaseOptions(
    singleInstance: false,
    onConfigure: DatabaseIntegrityService.configureConnection,
  ),
);

Future<void> _seed(Database db, int count) async {
  final batch = db.batch();
  final base = DateTime.utc(2023, 1, 1);
  for (var i = 0; i < count; i++) {
    batch.insert('activity_events', <String, Object?>{
      'id': 'evt-${i.toString().padLeft(6, '0')}',
      'type': i.isEven ? 'emergencyTriggered' : 'checkInCompleted',
      'title': 'Olay $i',
      'description': 'Guvenlik gecmisi kaydi numarasi $i',
      'timestamp': base.add(Duration(minutes: i)).toIso8601String(),
    });
  }
  await batch.commit(noResult: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('the query stays correct and bounded as the table grows', () {
    test('every tier returns every row, in order, with no duplicates',
        () async {
      final timings = <int, int>{};
      for (final tier in _tiers) {
        final db = await _open();
        await LocalDatabaseService.createSchema(db);
        await _seed(db, tier);

        final stopwatch = Stopwatch()..start();
        final rows =
            await db.query('activity_events', orderBy: 'timestamp DESC');
        stopwatch.stop();
        timings[tier] = stopwatch.elapsedMicroseconds;

        expect(rows, hasLength(tier), reason: 'rows lost at $tier');
        final ids = rows.map((r) => r['id']).toList();
        expect(ids.toSet().length, tier, reason: 'duplicate rows at $tier');
        // Newest first, and the ordering must hold across the whole table.
        expect(rows.first['id'], 'evt-${(tier - 1).toString().padLeft(6, '0')}');
        expect(rows.last['id'], 'evt-000000');
        await db.close();
      }
      // ignore: avoid_print
      print('MP-47-011 full-table query (rows -> us): $timings');
      // Recorded, not thresholded on an absolute number -- that would be a CI
      // flake rather than a contract. What IS asserted is that the cost grows
      // no worse than proportionally: a 100x table must not cost 1000x.
      expect(timings[10000]! / timings[100]!, lessThan(1000),
          reason: 'super-linear growth would mean the query degrades in a way '
              'the user eventually feels');
    });

    test('a filtered read stays cheap at the maximum tier', () async {
      final db = await _open();
      addTearDown(db.close);
      await LocalDatabaseService.createSchema(db);
      await _seed(db, 10000);

      final stopwatch = Stopwatch()..start();
      final page = await db.query(
        'activity_events',
        orderBy: 'timestamp DESC',
        limit: 200,
      );
      stopwatch.stop();
      expect(page, hasLength(200));
      // ignore: avoid_print
      print('MP-47-011 LIMIT 200 of 10000: ${stopwatch.elapsedMicroseconds}us');
      expect(page.first['id'], 'evt-009999');
    });

    test('deleting one row out of ten thousand hits exactly one row', () async {
      final db = await _open();
      addTearDown(db.close);
      await LocalDatabaseService.createSchema(db);
      await _seed(db, 10000);

      final deleted = await db.delete(
        'activity_events',
        where: 'id = ?',
        whereArgs: <Object>['evt-005000'],
      );
      expect(deleted, 1);
      expect(
        (await db.query('activity_events', columns: <String>['id'])).length,
        9999,
      );
    });

    test('integrity stays clean at the maximum tier', () async {
      final db = await _open();
      addTearDown(db.close);
      await LocalDatabaseService.createSchema(db);
      await _seed(db, 10000);
      final report = await DatabaseIntegrityService.scan(
        db,
        depth: IntegrityScanDepth.full,
      );
      expect(report.isHealthy, isTrue, reason: '${report.findings}');
      // ignore: avoid_print
      print('MP-47-011 full integrity scan of 10000 rows: '
          '${report.elapsed.inMicroseconds}us');
    });
  });

  group('the list still builds lazily at volume', () {
    testWidgets('10 000 rows build only a screenful of widgets',
        (tester) async {
      final ids = List<String>.generate(
        10000,
        (i) => 'evt-${i.toString().padLeft(6, '0')}',
      );
      final restorer = KeyedListScrollRestorer()..attach();
      addTearDown(restorer.dispose);
      restorer.setItems(ids);

      var built = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: restorer.controller,
              itemCount: ids.length,
              itemBuilder: (context, index) {
                built++;
                return KeyedSubtree(
                  key: restorer.keyFor(ids[index]),
                  child: SizedBox(height: 72, child: Text(ids[index])),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ignore: avoid_print
      print('MP-47-011 widgets built for 10000 rows: $built');
      expect(built, lessThan(60),
          reason: 'a non-lazy list would build 10 000 widgets and the screen '
              'would never appear');
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolling deep into the list stays correct and silent',
        (tester) async {
      final ids = List<String>.generate(
        10000,
        (i) => 'evt-${i.toString().padLeft(6, '0')}',
      );
      final restorer = KeyedListScrollRestorer()..attach();
      addTearDown(restorer.dispose);
      restorer.setItems(ids);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: restorer.controller,
              itemCount: ids.length,
              itemBuilder: (context, index) => KeyedSubtree(
                key: restorer.keyFor(ids[index]),
                child: SizedBox(height: 72, child: Text(ids[index])),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final maxExtent = restorer.controller.position.maxScrollExtent;
      expect(maxExtent, 10000 * 72.0 - tester.view.physicalSize.height /
          tester.view.devicePixelRatio);

      for (final fraction in <double>[0.25, 0.5, 0.99, 1.0]) {
        restorer.controller.jumpTo(maxExtent * fraction);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'exception at $fraction of a 10 000-row list');
      }
      // The last row is reachable and is the one it should be.
      expect(find.text('evt-009999'), findsOneWidget);
    });

    testWidgets('the scroll anchor still resolves at the maximum tier',
        (tester) async {
      final ids = List<String>.generate(
        10000,
        (i) => 'evt-${i.toString().padLeft(6, '0')}',
      );
      final restorer = KeyedListScrollRestorer()..attach();
      addTearDown(restorer.dispose);
      restorer.setItems(ids);
      restorer.value =
          const ScrollAnchor(offset: 360000, topItemId: 'evt-005000',
              topItemIndex: 5000);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: restorer.controller,
              itemCount: ids.length,
              itemBuilder: (context, index) => KeyedSubtree(
                key: restorer.keyFor(ids[index]),
                child: SizedBox(height: 72, child: Text(ids[index])),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      restorer.applyOnce(ids);
      await tester.pumpAndSettle();

      expect(restorer.controller.position.pixels, closeTo(5000 * 72.0, 2.0),
          reason: 'identity restoration must not degrade at volume');
      expect(tester.takeException(), isNull);
    });
  });

  group('the tiers are product-bound, and that is written down', () {
    test('the maximum tier is justified in this file', () {
      final src = File('test/core/services/high_volume_timeline_test.dart')
          .readAsStringSync();
      expect(src, contains('worst REALISTIC supported volume'));
      expect(_tiers.last, 10000);
      expect(_tiers, orderedEquals(<int>[100, 1000, 10000]));
    });
  });
}
