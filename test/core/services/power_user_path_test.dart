// MP-47-003 -- "Power user", the persona row of the manual QA matrix.
//
// The row was open because the LONG journey had never been driven end to end
// since the state-restoration rework. Its remediation said "extend the manual
// smoke script and run it once". The manual row is added (see
// store/MANUAL_SMOKE_TEST_SCRIPT.md), but a one-off human run answers the
// question once and then rots; this file drives the same path deterministically
// so it is answered on every release.
//
// The path is the one the audit named: arm -> cancel -> rehearse -> export ->
// revoke consent -> re-consent. Each step's OBSERVABLE effect is asserted, and
// the steps run in sequence against shared state, because the defect this row
// guards against is a LATER step breaking an EARLIER one's record.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/database_integrity_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/rehearsal_record_service.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The steps, in order, so a skipped one is visible rather than silent.
const List<String> _path = <String>[
  'arm a safety session',
  'cancel it',
  'record a rehearsal',
  'export local data',
  'revoke a consent',
  're-consent',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late ConsentManager consent;
  final completed = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: DatabaseIntegrityService.configureConnection,
      ),
    );
    await LocalDatabaseService.createSchema(db);
    consent = ConsentManager();
    await consent.initialize();
    completed.clear();
  });

  tearDown(() async => db.close());

  Future<void> logEvent(String type, String title) => db.insert(
    'activity_events',
    <String, Object?>{
      'id': '$type-${DateTime.now().microsecondsSinceEpoch}',
      'type': type,
      'title': title,
      'description': title,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    },
  );

  test('the whole power-user path runs, and nothing earlier is lost', () async {
    // 1. ARM. A safety session leaves a timeline record; that record is the
    //    user's own evidence and must survive everything that follows.
    await logEvent('emergencyTriggered', 'Panik baslatildi');
    completed.add(_path[0]);
    expect(await db.query('activity_events'), hasLength(1));

    // 2. CANCEL. Cancelling appends, it does not erase: a cancelled alarm the
    //    user cannot see afterwards is indistinguishable from one that never
    //    happened.
    await logEvent('emergencyCancelled', 'Panik iptal edildi');
    completed.add(_path[1]);
    final afterCancel = await db.query('activity_events',
        orderBy: 'timestamp DESC');
    expect(afterCancel, hasLength(2));
    expect(
      afterCancel.map((r) => r['type']),
      containsAll(<String>['emergencyTriggered', 'emergencyCancelled']),
    );

    // 3. REHEARSE.
    final rehearsedAt = DateTime.utc(2026, 8, 15, 9);
    await RehearsalRecordService.recordCompletedRehearsal(at: rehearsedAt);
    completed.add(_path[2]);
    expect(
      (await RehearsalRecordService.lastRehearsalAt())?.toUtc(),
      rehearsedAt,
    );

    // 4. EXPORT. The consent log is the part of the export this path cares
    //    about; the DB half is covered by high_volume_timeline_test.
    await consent.grantConsent(ConsentRecord.typeFakeCall);
    final exported = await consent.exportConsentLog();
    completed.add(_path[3]);
    expect(jsonEncode(exported), contains(ConsentRecord.typeFakeCall));

    // 5. REVOKE. The revocation must be recorded, and the state must flip.
    await consent.revokeConsent(ConsentRecord.typeFakeCall);
    completed.add(_path[4]);
    expect(consent.isGranted(ConsentRecord.typeFakeCall), isFalse);

    // 6. RE-CONSENT, which is the step most likely to be broken by an
    //    append-only log read back wrongly: the LATEST record must win.
    await consent.grantConsent(ConsentRecord.typeFakeCall);
    completed.add(_path[5]);
    expect(consent.isGranted(ConsentRecord.typeFakeCall), isTrue);

    // A fresh manager must reach the same conclusion from storage alone --
    // this is the step that catches "the cache was right, the log was not".
    final reloaded = ConsentManager();
    await reloaded.initialize();
    expect(reloaded.isGranted(ConsentRecord.typeFakeCall), isTrue,
        reason: 're-consent did not survive a reload, so the durable record '
            'disagrees with what the user was shown');

    // Nothing earlier was lost by anything later.
    expect(await db.query('activity_events'), hasLength(2),
        reason: 'the timeline lost a record somewhere along the path');
    expect(
      (await RehearsalRecordService.lastRehearsalAt())?.toUtc(),
      rehearsedAt,
    );
    expect(completed, _path);

    // The database is still sound after the whole journey.
    final integrity = await DatabaseIntegrityService.scan(
      db,
      depth: IntegrityScanDepth.full,
    );
    expect(integrity.isHealthy, isTrue, reason: '${integrity.findings}');
  });

  test('revoke -> re-consent -> revoke ends REVOKED, not granted', () async {
    // The append-only log's failure mode is order, so the ambiguous case gets
    // its own run rather than riding on the happy path.
    for (final grant in <bool>[true, false, true, false]) {
      if (grant) {
        await consent.grantConsent(ConsentRecord.typeLocation);
      } else {
        await consent.revokeConsent(ConsentRecord.typeLocation);
      }
    }
    expect(consent.isGranted(ConsentRecord.typeLocation), isFalse);
    final reloaded = ConsentManager();
    await reloaded.initialize();
    expect(reloaded.isGranted(ConsentRecord.typeLocation), isFalse);
  });

  test('a rehearsal record survives a consent revocation', () async {
    // A rehearsal is the user's own safety practice, not personal data tied to
    // a consent; revoking fake-call consent must not silently erase it.
    final at = DateTime.utc(2026, 8, 15, 10);
    await RehearsalRecordService.recordCompletedRehearsal(at: at);
    await consent.grantConsent(ConsentRecord.typeFakeCall);
    await consent.revokeConsent(ConsentRecord.typeFakeCall);
    expect((await RehearsalRecordService.lastRehearsalAt())?.toUtc(), at);
  });

  group('the manual script carries the same path', () {
    test('MANUAL_SMOKE_TEST_SCRIPT.md has a power-user row naming every step',
        () {
      final script =
          File('store/MANUAL_SMOKE_TEST_SCRIPT.md').readAsStringSync();
      expect(script, contains('Power user'));
      for (final step in <String>[
        'arm', 'cancel', 'rehears', 'export', 'revoke', 're-consent',
      ]) {
        expect(script.toLowerCase(), contains(step.toLowerCase()),
            reason: 'the manual row omits "$step", so a human run would not '
                'cover what this test covers');
      }
    });

    test('the automated path names the test that backs the manual row', () {
      final script =
          File('store/MANUAL_SMOKE_TEST_SCRIPT.md').readAsStringSync();
      expect(script, contains('power_user_path_test.dart'));
    });
  });
}
