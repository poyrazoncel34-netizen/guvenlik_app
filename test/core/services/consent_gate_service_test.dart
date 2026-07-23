import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:guvenlik_app/core/services/consent_gate_service.dart';

void main() {
  setUp(() {
    GetIt.instance.reset();
  });

  test('isEmergencyContactsAllowed returns false when the consent authority '
      'is unavailable so a new safety arm cannot process contact data', () {
    // Do NOT register ConsentManager in GetIt.
    expect(ConsentGateService.isEmergencyContactsAllowed(), isFalse);
  });

  test(
    'isAudioAllowed returns false (fail-closed) when '
    'ConsentManager is not registered — non-emergency features stay safe',
    () {
      // Non-emergency consent types must remain fail-closed.
      expect(ConsentGateService.isAudioAllowed(), isFalse);
    },
  );
}
