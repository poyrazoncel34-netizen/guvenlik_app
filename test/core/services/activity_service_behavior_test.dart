// Behaviour of the safety timeline store, on a real (ffi) SQLite database.
//
// Audit A-09: an event logged without an explicit id took
// `millisecondsSinceEpoch` as its primary key and was inserted with
// `ConflictAlgorithm.abort`. Two events in the same millisecond -- easy for two
// independent features reacting to one moment -- made the second insert throw,
// and several callers fire-and-forget the call, so the event vanished from the
// user's safety history and the failure surfaced only as an unhandled error.
// The existing activity_service_test.dart is a source-string check; these run
// the production code.

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/services/activity_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/domain/models/activity_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Database extends LocalDatabaseService {
  _Database(this.db);
  final Database db;
  @override
  Future<Database> get database async => db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await LocalDatabaseService.createSchema(db);
    await serviceLocator.reset();
    serviceLocator.registerSingleton<LocalDatabaseService>(_Database(db));
  });

  tearDown(() async {
    await db.close();
    await serviceLocator.reset();
  });

  test('events logged in the same millisecond are all kept', () async {
    // Both ids are computed before either insert awaits, so they share a
    // millisecond deterministically.
    await Future.wait(<Future<void>>[
      for (var i = 0; i < 5; i++)
        ActivityService.logEvent(
          type: ActivityType.safetyCheck,
          title: 'event $i',
          description: 'same moment',
        ),
    ]);

    final events = await ActivityService.getEvents();
    expect(events.map((e) => e.title).toSet(), {
      for (var i = 0; i < 5; i++) 'event $i',
    });
    expect(events.map((e) => e.id).toSet(), hasLength(5));
  });

  test('an explicit id stays idempotent', () async {
    for (var i = 0; i < 3; i++) {
      await ActivityService.logEvent(
        eventId: 'native-session-1',
        type: ActivityType.emergencyTriggered,
        title: 'once',
        description: 'replayed outcome',
      );
    }
    expect(await ActivityService.getEvents(), hasLength(1));
  });

  test('the retention limit is enforced on insert', () async {
    final base = DateTime(2026, 1, 1);
    for (var i = 0; i < 205; i++) {
      await ActivityService.logEvent(
        type: ActivityType.safetyCheck,
        title: 'e$i',
        description: '',
        timestamp: base.add(Duration(minutes: i)),
      );
    }
    final events = await ActivityService.getEvents();
    expect(events, hasLength(200));
    expect(events.first.title, 'e204', reason: 'newest kept');
    expect(events.any((e) => e.title == 'e0'), isFalse, reason: 'oldest gone');
  });
}
