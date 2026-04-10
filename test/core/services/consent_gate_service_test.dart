import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:guvenlik_app/core/services/consent_gate_service.dart';

void main() {
  setUp(() {
    GetIt.instance.reset();
  });

  test(
    'isEmergencyContactsAllowed returns true (fail-open) when '
    'ConsentManager is not registered — emergency must never be blocked',
    () {
      // Do NOT register ConsentManager in GetIt.
      // If the DI container fails to initialize, emergency calls
      // must NOT be silently blocked in a life-critical app.
      expect(ConsentGateService.isEmergencyContactsAllowed(), isTrue);
    },
  );

  test(
    'isAudioAllowed returns false (fail-closed) when '
    'ConsentManager is not registered — non-emergency features stay safe',
    () {
      // Non-emergency consent types must remain fail-closed.
      expect(ConsentGateService.isAudioAllowed(), isFalse);
    },
  );
}
