import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Blocker 2: exact alarm degraded state must be visible in the readiness card.
///
/// When SCHEDULE_EXACT_ALARM is not granted, the native backup alarm falls back
/// to inexact scheduling, which can be delayed significantly under Doze mode.
/// This degraded state must be shown to the user as a readiness chip — not
/// silently ignored.
void main() {
  late String home;
  late String card;
  late String level;

  setUpAll(() {
    home = File('lib/screens/home_page.dart').readAsStringSync();
    // The card moved out of home_page into its own widget; the contract
    // follows the card, and home_page still has to feed it the live snapshot.
    card = File('lib/core/widgets/readiness_card.dart').readAsStringSync();
    // OD-2 (2026-10-11): the headline verdict moved again, into the one place
    // every surface now derives its words from. Assertions about what "ready"
    // MEANS belong there; assertions about what the card DOES stay on the card.
    level = File(
      'lib/core/services/safety_readiness_level.dart',
    ).readAsStringSync();
  });

  test(
    'readiness card reads typed platform readiness from the service',
    () {
      expect(
        home,
        contains('EmergencyReadinessService'),
        reason:
            'home_page must read EmergencyReadinessService to surface exact alarm state',
      );
      expect(
        home,
        contains('EmergencyReadinessService.instance.lastState'),
        reason: 'the card must be fed the live snapshot, not a stale copy',
      );
      expect(card, contains('backgroundAlertReady'));
      expect(
        level,
        contains('criticalSafetyReady'),
        reason:
            'the single readiness verdict must be built on the platform '
            'snapshot that the dispatch path uses',
      );
    },
  );

  test(
    'readiness card never defaults an unchecked safety capability to true',
    () {
      expect(card, isNot(contains('exactAlarmPermission ?? true')));
      expect(card, isNot(contains('backgroundAlertReady ?? true')));
      expect(card, isNot(contains('criticalSafetyReady ?? true')));
      expect(card, isNot(contains('automaticCallReady ?? true')));
      expect(level, isNot(contains('criticalSafetyReady ?? true')));
      expect(card, contains('backgroundAlertReady'));
      // A null or unknown snapshot must never fall through to ready. Checked on
      // the verdict, which is now the only thing that can make that mistake.
      expect(level, contains('SafetyReadinessLevel.unavailable'));
    },
  );

  test('a complete setup cannot be claimed without criticalSafetyReady', () {
    // The expression this used to pin verbatim
    // (`missing.isEmpty && _criticalSafetyReady`) became
    // `missing.isEmpty && level == SafetyReadinessLevel.fullyReady` under OD-2,
    // because copy and runtime state had to stop being derived separately. The
    // requirement is unchanged and is asserted in two halves:
    expect(
      card,
      contains('missing.isEmpty && level == SafetyReadinessLevel.fullyReady'),
      reason:
          'green chips alone must not headline "setup complete"; the platform '
          'verdict has to agree',
    );
    expect(
      level,
      contains('''snapshot.criticalSafetyReady
        ? SafetyReadinessLevel.fullyReady'''),
      reason: 'fullyReady must mean exactly criticalSafetyReady',
    );
    // ...and by behaviour, not only by source text: the OD-2 widget test
    // asserts a missing exact alarm yields `limited`, never `fullyReady`.
    expect(
      File('test/screens/od2_background_protection_step_test.dart').existsSync(),
      isTrue,
    );
  });
}
