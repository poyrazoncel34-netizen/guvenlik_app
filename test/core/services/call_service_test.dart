import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/call_service.dart';

/// M3: Phone number validation — numbers shorter than 7 digits should fail.
/// H4: Consent gate should not block emergency calls.
void main() {
  test('startEmergencyCall rejects phone numbers shorter than 7 digits', () async {
    // '123' has only 3 digits — should fail validation
    final result = await CallService.startEmergencyCall('123');
    expect(result.isSuccess, isFalse);
    expect(result.status, EmergencyCallStatus.failed);
  });
}
