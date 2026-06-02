import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SPEC 0 Karar 1/2 + 3.2 + 7 ("112/failover CAGRILMAZ"):
/// the check-in expiry path must call ONLY the primary number — no multi-number
/// failover loop, no 112 default — and must dedup against the native-fired flag
/// before placing a Dart call.
void main() {
  late String triggerBody;

  setUpAll(() {
    final source = File(
      'lib/core/services/check_in_service.dart',
    ).readAsStringSync();
    final start = source.indexOf('_triggerEmergency(');
    expect(start, isNot(-1), reason: '_triggerEmergency must exist');
    // Body up to the next top-level private method declaration after it.
    final next = source.indexOf('Future<void> _startBackgroundProtection', start);
    triggerBody = source.substring(start, next == -1 ? source.length : next);
  });

  test('does not run a multi-number failover loop', () {
    expect(
      triggerBody.contains('for (final fallbackNumber in numbers)'),
      isFalse,
      reason: 'Check-in escalation must not iterate fallback numbers (no failover).',
    );
  });

  test('does not synthesize 112 / turkeyEmergencyNumber as a default target', () {
    expect(
      triggerBody.contains('AppConstants.turkeyEmergencyNumber'),
      isFalse,
      reason: 'Check-in escalation must never fall back to 112.',
    );
  });

  test('checks the native-fired dedup flag before placing a Dart call', () {
    expect(
      triggerBody.contains('didCheckInAlarmFire'),
      isTrue,
      reason: 'Dart path must skip when the native backup already fired.',
    );
  });
}
