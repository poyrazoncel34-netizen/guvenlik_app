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

  setUpAll(() {
    home = File('lib/screens/home_page.dart').readAsStringSync();
    // The card moved out of home_page into its own widget; the contract
    // follows the card, and home_page still has to feed it the live snapshot.
    card = File('lib/core/widgets/readiness_card.dart').readAsStringSync();
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
      expect(card, contains('criticalSafetyReady'));
    },
  );

  test(
    'readiness card never defaults an unchecked safety capability to true',
    () {
      expect(card, isNot(contains('exactAlarmPermission ?? true')));
      expect(card, isNot(contains('backgroundAlertReady ?? true')));
      expect(card, isNot(contains('criticalSafetyReady ?? true')));
      expect(card, isNot(contains('automaticCallReady ?? true')));
      expect(card, contains('criticalSafetyReady'));
      expect(card, contains('backgroundAlertReady'));
    },
  );

  test('a complete setup cannot be claimed without criticalSafetyReady', () {
    expect(
      card,
      contains('missing.isEmpty && _criticalSafetyReady'),
      reason:
          'green chips alone must not headline "setup complete" when the '
          'platform snapshot says the flow cannot run',
    );
  });
}
