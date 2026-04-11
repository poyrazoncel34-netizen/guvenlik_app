import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CallService must not promise call-connection guarantees. Android can start
/// a direct call or prepare the dialer; connection depends on carrier/device.
void main() {
  test('CallService should not expose retry-as-guarantee API', () {
    final source = File(
      'lib/core/services/call_service.dart',
    ).readAsStringSync();

    expect(
      source.contains('startEmergencyCallWithRetry'),
      isFalse,
      reason:
          'Retry API implies a guarantee and risks duplicate call attempts; countdown dispatch is single-shot with dialer fallback.',
    );
  });
}
