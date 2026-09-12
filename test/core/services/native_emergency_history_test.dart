import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/services/activity_service.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
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
  const channel = MethodChannel('native_history_acceptance');
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await serviceLocator.reset();
    await db.close();
  });

  test('failed SQLite commit leaves native outcome unacknowledged', () async {
    const token = SessionToken(
      protocolVersion: 1,
      randomId: 'failed-db',
      generation: 1,
      kind: EmergencySessionKind.panic,
    );
    var acknowledgements = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (request) async {
          if (request.method == 'acknowledgeEmergencyOutcome') {
            acknowledgements++;
          }
          return {
            'outcomes': [
              {
                'type': 'present',
                'session': {
                  'token': token.toMap(),
                  'lifecycleState': 'requestFailed',
                  'mainDeadlineMs': 1000,
                  'finalDeadlineMs': 2000,
                  'target': '',
                  'callRequestOutcome': 'failed',
                  'fallbackOutcome': 'failed',
                },
              },
            ],
          };
        });
    await db.execute('DROP TABLE activity_events');
    await expectLater(
      NativeEmergencyHistory.reconcilePending(
        EmergencyPlatformService.forTesting(methodChannel: channel),
      ),
      throwsA(anything),
    );
    expect(acknowledgements, 0);
  });

  for (final call in ['submittedUnconfirmed', 'failed']) {
    for (final fallback in ['posted', 'failed', 'notAttempted', 'expired']) {
      test(
        '$call / $fallback warm and cold reconciliation is idempotent',
        () async {
          const token = SessionToken(
            protocolVersion: 1,
            randomId: 'synthetic',
            generation: 4,
            kind: EmergencySessionKind.checkIn,
          );
          final outcome = {
            'type': 'present',
            'session': {
              'token': token.toMap(),
              'lifecycleState': call == 'submittedUnconfirmed'
                  ? 'requestSubmittedUnconfirmed'
                  : fallback == 'posted'
                  ? 'manualActionRequired'
                  : 'requestFailed',
              'completedAtMs': 1070000,
              'mainDeadlineMs': 1000000,
              'finalDeadlineMs': 1060000,
              'target': '',
              'callRequestOutcome': call,
              'fallbackOutcome': fallback,
            },
          };
          var acknowledgements = 0;
          var journalPending = true;
          final methods = <String>[];
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (request) async {
                methods.add(request.method);
                if (request.method == 'pendingEmergencyOutcomes') {
                  // Simulate lost acknowledgement: same journal entry is replayed.
                  return {
                    'outcomes': [if (journalPending) outcome],
                  };
                }
                if (request.method == 'acknowledgeEmergencyOutcome') {
                  expect((request.arguments as Map)['token'], token.toMap());
                  expect(await db.query('activity_events'), hasLength(1));
                  acknowledgements++;
                  return {'ok': true};
                }
                return outcome; // Terminal slot remains after journal ack.
              });
          EmergencyPlatformService platform() =>
              EmergencyPlatformService.forTesting(methodChannel: channel);
          await NativeEmergencyHistory.reconcilePending(platform());
          await NativeEmergencyHistory.reconcilePending(platform());
          final events = await ActivityService.getEvents();
          expect(events, hasLength(1));
          expect(events.single.id, NativeEmergencyHistory.eventId(token));
          expect(events.single.timestamp.millisecondsSinceEpoch, 1070000);
          expect(
            events.single.description,
            contains(
              call == 'submittedUnconfirmed'
                  ? 'native_history_request_submitted'
                  : 'native_history_request_failed',
            ),
          );
          if (fallback == 'notAttempted') {
            expect(
              events.single.description,
              isNot(contains('native_history_fallback')),
            );
          } else {
            expect(
              events.single.description,
              contains('native_history_fallback_$fallback'),
            );
          }
          journalPending = false;
          await ActivityService.deleteEvent(events.single.id);
          await NativeEmergencyHistory.reconcilePending(platform());
          expect(
            await ActivityService.getEvents(),
            isEmpty,
            reason:
                'Acknowledged terminal slots must not recreate user-deleted history.',
          );
          expect(acknowledgements, 2);
          expect(methods, isNot(contains('dispatchEmergencySession')));
          expect(methods, isNot(contains('armEmergencySession')));
        },
      );
    }
  }
}
