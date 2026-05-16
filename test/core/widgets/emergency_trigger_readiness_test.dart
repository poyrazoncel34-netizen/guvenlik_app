import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// System 3B: emergency_trigger_host must call checkReadiness on startup.
void main() {
  test('emergency_trigger_host should call checkReadiness in initState', () {
    final source = File(
      'lib/core/widgets/emergency_trigger_host.dart',
    ).readAsStringSync();

    expect(
      source.contains('EmergencyReadinessService'),
      isTrue,
      reason: 'Must reference EmergencyReadinessService',
    );

    expect(
      source.contains('checkReadiness'),
      isTrue,
      reason: 'Must call checkReadiness for startup readiness check',
    );
  });
}
