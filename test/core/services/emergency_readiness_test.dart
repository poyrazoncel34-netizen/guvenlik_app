import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// System 3A: EmergencyReadinessService must exist with checkReadiness method.
void main() {
  test('EmergencyReadinessService should have checkReadiness method', () {
    final file = File('lib/core/services/emergency_readiness_service.dart');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'emergency_readiness_service.dart must exist',
    );

    final source = file.readAsStringSync();
    expect(
      source.contains('checkReadiness'),
      isTrue,
      reason: 'Must have checkReadiness method',
    );
    expect(
      source.contains('getDeviceState'),
      isTrue,
      reason: 'Must use getDeviceState for battery optimization check',
    );
  });
}
