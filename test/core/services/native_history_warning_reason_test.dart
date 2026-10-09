// A-03 (owner decision 2026-10-09): the Check-In / Safe Walk final warning is
// BEST EFFORT -- a warning that could not be shown never moves or cancels the
// final deadline -- but the safety timeline must say why it was not shown.
// Native carries the outcome in the terminal journal ("posted", "failed",
// "unknown", or still "notAttempted" when the alarm never got to it).

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/services/activity_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/emergency_snapshot_parser.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/native_emergency_history.dart';
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
    await serviceLocator.reset();
    await db.close();
  });

  Future<String> recordedDescription(
    EmergencySessionKind kind,
    String? graceWarningOutcome, {
    String randomId = 'warning-reason',
  }) async {
    final token = SessionToken(
      protocolVersion: 1,
      randomId: randomId,
      generation: 1,
      kind: kind,
    );
    final snapshot = parseSessionSnapshot({
      'type': 'present',
      'session': {
        'token': token.toMap(),
        'lifecycleState': 'requestSubmittedUnconfirmed',
        'mainDeadlineMs': 1000,
        'finalDeadlineMs': 61000,
        'completedAtMs': 61500,
        'target': '',
        'callRequestOutcome': 'submittedUnconfirmed',
        'fallbackOutcome': 'posted',
        'graceWarningOutcome': ?graceWarningOutcome,
      },
    });
    await NativeEmergencyHistory.record(snapshot);
    final events = await ActivityService.getEvents();
    return events.single.description;
  }

  test(
    'a warning the system refused to post is named in the timeline',
    () async {
      final text = await recordedDescription(
        EmergencySessionKind.checkIn,
        'failed',
      );
      expect(text, contains('native_history_warning_failed'));
    },
  );

  test('a warning that never got to run is named in the timeline', () async {
    final text = await recordedDescription(
      EmergencySessionKind.safeWalk,
      'notAttempted',
    );
    expect(text, contains('native_history_warning_missed'));
  });

  test('a warning whose post was never confirmed says so', () async {
    final text = await recordedDescription(
      EmergencySessionKind.checkIn,
      'unknown',
    );
    expect(text, contains('native_history_warning_unknown'));
  });

  test(
    'a shown warning, a panic and an older native build add nothing',
    () async {
      for (final (kind, outcome, id)
          in <(EmergencySessionKind, String?, String)>[
            (EmergencySessionKind.checkIn, 'posted', 'posted-1'),
            (EmergencySessionKind.panic, 'notAttempted', 'panic-1'),
            (EmergencySessionKind.checkIn, null, 'legacy-1'),
          ]) {
        await db.delete('activity_events');
        final text = await recordedDescription(kind, outcome, randomId: id);
        expect(text, isNot(contains('native_history_warning_')), reason: id);
      }
    },
  );
}
