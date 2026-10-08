// Y-08 (chaos audit 2026-10-08): the panic timeline row came ONLY from the
// native journal. When the native arm is refused for a foreground-dial reason
// (callPermissionDenied, exactAlarmDenied, notificationsDisabled,
// alertChannelNotHigh) the countdown still runs and ends in ACTION_DIAL, but
// no native session exists, so nothing was ever journaled: on an API 35
// emulator a real panic with CALL_PHONE revoked opened the dialer at 14:49:06
// and activity_events held no row for it. Notification-denied users hit this
// on every panic.

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/services/activity_service.dart';
import 'package:guvenlik_app/core/services/dispatch_outcome.dart';
import 'package:guvenlik_app/core/services/emergency_bookkeeping.dart';
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

  Future<void> runTimelineStep({required bool nativeJournal}) async {
    final step = EmergencyBookkeeping.panicStepsWithDefaultCopy(
      nativeJournal: nativeJournal,
    ).singleWhere((s) => s.target == DispatchTarget.safetyTimeline);
    await step.run();
  }

  test('a panic with no native session writes its own timeline row', () async {
    await runTimelineStep(nativeJournal: false);

    final events = await ActivityService.getEvents();
    expect(events, hasLength(1));
    expect(events.single.type, ActivityType.emergencyTriggered);
  });

  test('a panic with a native session leaves the row to the native journal '
      '(no duplicate)', () async {
    await runTimelineStep(nativeJournal: true);

    expect(await ActivityService.getEvents(), isEmpty);
  });
}
