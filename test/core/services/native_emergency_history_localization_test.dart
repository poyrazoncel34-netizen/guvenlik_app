// A native outcome recorded while Flutter was dead must reach the timeline as
// translated text, and must never be consumed from the native journal before
// that text is durably in the database.
//
// Reproduced on an API 35 emulator before the fix: a cold start reconciled the
// journal from EmergencyTriggerHost.initState -- above MaterialApp, before its
// delegate had loaded the catalogue -- and the timeline kept
// "countdown_emergency_title / native_history_request_submitted ..." forever.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      _trCatalogue();
}

Map<String, dynamic> _trCatalogue() =>
    jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
        as Map<String, dynamic>;

const _token = SessionToken(
  protocolVersion: 1,
  randomId: 'cold-start-l10n',
  generation: 1,
  kind: EmergencySessionKind.panic,
);

/// A fake native journal that records the ORDER of what happened to it.
class _Journal {
  bool pending = true;
  final events = <String>[];
  int rowsAtAck = -1;

  void install(MethodChannel channel, Database db) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'pendingEmergencyOutcomes') {
            events.add('read');
            return {
              'outcomes': [
                if (pending)
                  {
                    'type': 'present',
                    'session': {
                      'token': _token.toMap(),
                      'lifecycleState': 'requestSubmittedUnconfirmed',
                      'mainDeadlineMs': 1000,
                      'finalDeadlineMs': 1000,
                      'completedAtMs': 2000,
                      'target': '',
                      'callRequestOutcome': 'submittedUnconfirmed',
                      'fallbackOutcome': 'posted',
                    },
                  },
              ],
            };
          }
          if (call.method == 'acknowledgeEmergencyOutcome') {
            rowsAtAck = (await db.query('activity_events')).length;
            events.add('ack');
            pending = false;
            return {'acknowledged': true};
          }
          return null;
        });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('native_history_localization');
  late Database db;
  late _Journal journal;
  final defaultReadiness = NativeEmergencyHistory.translationsReady;

  EmergencyPlatformService platform() =>
      EmergencyPlatformService.forTesting(methodChannel: channel);

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
    NativeEmergencyHistory.translationsReady = defaultReadiness;
    journal = _Journal()..install(channel, db);
  });

  tearDown(() async {
    NativeEmergencyHistory.translationsReady = defaultReadiness;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await serviceLocator.reset();
    await db.close();
  });

  test('before the catalogue loads, nothing is written and nothing is '
      'consumed from the native journal', () async {
    expect(
      NativeEmergencyHistory.translationsReady(),
      isFalse,
      reason: 'precondition: this isolate has no catalogue loaded',
    );

    await NativeEmergencyHistory.reconcilePending(platform());

    expect(await ActivityService.getEvents(), isEmpty);
    expect(journal.events, isNot(contains('ack')));
    expect(journal.pending, isTrue, reason: 'outcome must stay retryable');
  });

  test('reconcileWhenReady waits for the catalogue, then writes before it '
      'acknowledges', () async {
    var polls = 0;
    NativeEmergencyHistory.translationsReady = () => ++polls > 3;

    await NativeEmergencyHistory.reconcileWhenReady(
      platform(),
      pollInterval: const Duration(milliseconds: 5),
    );

    expect(await ActivityService.getEvents(), hasLength(1));
    expect(journal.events.last, 'ack');
    expect(
      journal.rowsAtAck,
      1,
      reason: 'the journal entry was consumed before the row was durable',
    );
  });

  test('a catalogue that never loads leaves the outcome pending', () async {
    NativeEmergencyHistory.translationsReady = () => false;

    await NativeEmergencyHistory.reconcileWhenReady(
      platform(),
      pollInterval: const Duration(milliseconds: 1),
      maxPolls: 3,
    );

    expect(await ActivityService.getEvents(), isEmpty);
    expect(journal.events, isNot(contains('ack')));
  });

  test('a failed database write is never acknowledged', () async {
    NativeEmergencyHistory.translationsReady = () => true;
    await db.execute('DROP TABLE activity_events');

    await expectLater(
      NativeEmergencyHistory.reconcilePending(platform()),
      throwsA(anything),
    );
    expect(journal.events, isNot(contains('ack')));
    expect(journal.pending, isTrue);
  });

  testWidgets('with the real catalogue loaded the timeline gets Turkish text, '
      'never the raw keys', (tester) async {
    await tester.runAsync(() async {
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('tr', 'TR')],
          path: 'assets/translations',
          assetLoader: const _RealTrAssetLoader(),
          startLocale: const Locale('tr', 'TR'),
          fallbackLocale: const Locale('tr', 'TR'),
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: const SizedBox(),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(NativeEmergencyHistory.translationsReady(), isTrue);

    await tester.runAsync(
      () => NativeEmergencyHistory.reconcilePending(platform()),
    );
    final events = await tester.runAsync(ActivityService.getEvents);

    final catalogue = _trCatalogue();
    final event = events!.single;
    expect(event.title, catalogue['countdown_emergency_title']);
    expect(
      event.description,
      contains(catalogue['native_history_request_submitted'] as String),
    );
    expect(event.title, isNot(contains('countdown_emergency_title')));
    expect(event.description, isNot(contains('native_history_')));
    expect(journal.rowsAtAck, 1);
  });

  test('the cold-start reconcile in EmergencyTriggerHost waits for the '
      'catalogue', () {
    final source = File(
      'lib/core/widgets/emergency_trigger_host.dart',
    ).readAsStringSync();
    final initState = source.substring(
      source.indexOf('void initState() {'),
      source.indexOf('Future<void> _consumeQuickPanicRequest()'),
    );
    expect(
      initState,
      contains('_reconcilePendingHistory(waitForTranslations: true)'),
      reason: 'initState runs above MaterialApp, before the catalogue loads',
    );
    expect(source, contains('NativeEmergencyHistory.reconcileWhenReady('));
  });
}
