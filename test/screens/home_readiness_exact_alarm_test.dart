import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Blocker 2: exact alarm degraded state must be visible in the readiness card.
///
/// When SCHEDULE_EXACT_ALARM is not granted, the native backup alarm falls back
/// to inexact scheduling, which can be delayed significantly under Doze mode.
/// This degraded state must be shown to the user as a readiness chip — not
/// silently ignored.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/home_page.dart').readAsStringSync();
  });

  test(
    'readiness card reads exactAlarmPermission from EmergencyReadinessService',
    () {
      expect(
        source,
        contains('EmergencyReadinessService'),
        reason:
            'home_page must import/use EmergencyReadinessService to surface exact alarm state',
      );
      expect(
        source,
        contains('exactAlarmPermission'),
        reason:
            'readiness card must check exactAlarmPermission to detect degraded state',
      );
    },
  );
}
