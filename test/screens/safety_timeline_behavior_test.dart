import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/screens/safety_timeline_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

class _MemoryDatabaseService extends LocalDatabaseService {
  _MemoryDatabaseService(this.db);
  final Database db;

  @override
  Future<Database> get database async => db;
}

Future<void> _settleIo(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await LocalDatabaseService.createSchema(db);
    serviceLocator.registerSingleton<LocalDatabaseService>(
      _MemoryDatabaseService(db),
    );
  });
  tearDown(() async {
    await db.close();
    await serviceLocator.reset();
  });

  testWidgets('GCM-01/GCM-02/GCM-03 real timeline loads and saves a note', (
    tester,
  ) async {
    await pumpLocalized(tester, const SafetyTimelineScreen());
    await _settleIo(tester);

    expect(find.byType(SafetyTimelineScreen), findsOneWidget);
    expect(find.text('Henüz güvenlik etkinliği yok.'), findsOneWidget);

    await tester.tap(find.text('Yeni Not'));
    await tester.pumpAndSettle();
    expect(find.text('Not Ekle'), findsOneWidget);

    // Empty submit is the specified negative path: no write and sheet stays.
    final save = find.text('Kaydet');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(find.text('Not Ekle'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        'safety_timeline_notes',
      ),
      isNull,
    );

    await tester.enterText(find.byType(TextField).first, 'Kadıköy iskelesi');
    await tester.tap(save);
    await _settleIo(tester);

    expect(find.text('Not Ekle'), findsNothing);
    expect(find.text('Kadıköy iskelesi'), findsOneWidget);
    expect(find.text('Not kaydedildi!'), findsOneWidget);
    final saved = (await SharedPreferences.getInstance()).getStringList(
      'safety_timeline_notes',
    );
    expect(saved, hasLength(1));
    expect(jsonDecode(saved!.single)['destination'], 'Kadıköy iskelesi');
  });

  // Fault injection (audit §15): the activity store throws on read. The screen
  // awaited it without a catch, so it stayed on the spinner for good -- the
  // user's own notes never appeared -- and an empty list would have read as
  // "no safety activity" when the truth was "could not read it".
  testWidgets('an unreadable activity store still shows notes and says so', (
    tester,
  ) async {
    final note = <String, Object>{
      'id': 'note-1',
      'destination': 'Eve dönüş',
      'plan': '',
      'notes': '',
      'timestamp': DateTime(2026, 9, 24, 20).toIso8601String(),
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      'safety_timeline_notes': <String>[jsonEncode(note)],
    });
    // Real ffi I/O must leave the fake-async zone (it never completes in it).
    await tester.runAsync(() => db.execute('DROP TABLE activity_events'));

    await pumpLocalized(tester, const SafetyTimelineScreen());
    // Bounded: an endless spinner would never let pumpAndSettle return.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Eve dönüş'), findsOneWidget);
    expect(
      find.text('Güvenlik kayıtları okunamadı; liste eksik olabilir.'),
      findsOneWidget,
    );
  });

  testWidgets('GCM-05 delete cancel preserves, confirm permanently removes', (
    tester,
  ) async {
    final note = <String, Object>{
      'id': 'note-1',
      'destination': 'Eve dönüş',
      'plan': '',
      'notes': 'Otobüs',
      'timestamp': DateTime(2026, 9, 24, 20).toIso8601String(),
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      'safety_timeline_notes': <String>[jsonEncode(note)],
    });
    await pumpLocalized(tester, const SafetyTimelineScreen());
    await _settleIo(tester);
    expect(find.text('Eve dönüş'), findsOneWidget);

    Future<void> openDelete() async {
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(find.text('Bu kayit silinsin mi?'), findsOneWidget);
    }

    await openDelete();
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(find.text('Eve dönüş'), findsOneWidget);

    await openDelete();
    await tester.tap(find.text('Kalici olarak sil'));
    for (var round = 0; round < 10; round++) {
      await _settleIo(tester);
      if (find.text('Eve dönüş').evaluate().isEmpty) break;
    }
    expect(find.text('Eve dönüş'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        'safety_timeline_notes',
      ),
      isEmpty,
    );
  });
}
