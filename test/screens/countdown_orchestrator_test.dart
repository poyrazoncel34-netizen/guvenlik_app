import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// System 2B: countdown_screen must delegate emergency dispatch to
/// EmergencyOrchestrator instead of managing SMS+call channels directly.
void main() {
  test('countdown_screen should use EmergencyOrchestrator', () {
    final source = File('lib/screens/countdown_screen.dart').readAsStringSync();

    expect(
      source.contains('EmergencyOrchestrator.execute'),
      isTrue,
      reason: 'countdown_screen must delegate to EmergencyOrchestrator.execute',
    );

    expect(
      source.contains('emergency_orchestrator.dart'),
      isTrue,
      reason: 'countdown_screen must import emergency_orchestrator.dart',
    );
  });
}
