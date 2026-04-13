import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/check_in_expiry_coordinator.dart';

void main() {
  group('CheckInExpiryCoordinator', () {
    tearDown(() {
      CheckInExpiryCoordinator.instance.reset();
    });

    test('allows only one expiry claim for an armed safe-walk session', () {
      final coordinator = CheckInExpiryCoordinator.instance;
      coordinator.arm(CheckInExpiryCoordinator.safeWalkSession);

      expect(
        coordinator.tryClaim(
          'safe_walk_timer',
          sessionId: CheckInExpiryCoordinator.safeWalkSession,
        ),
        isTrue,
      );
      expect(coordinator.tryClaim('native_check_in_expired'), isFalse);
    });

    test('rejects a claim for a different active session', () {
      final coordinator = CheckInExpiryCoordinator.instance;
      coordinator.arm(CheckInExpiryCoordinator.checkInSession);

      expect(
        coordinator.tryClaim(
          'safe_walk_timer',
          sessionId: CheckInExpiryCoordinator.safeWalkSession,
        ),
        isFalse,
      );
      expect(
        coordinator.tryClaim(
          'check_in_service',
          sessionId: CheckInExpiryCoordinator.checkInSession,
        ),
        isTrue,
      );
    });

    test('allows safe-walk and check-in claims to stay isolated', () {
      final coordinator = CheckInExpiryCoordinator.instance;
      coordinator
        ..arm(CheckInExpiryCoordinator.safeWalkSession)
        ..arm(CheckInExpiryCoordinator.checkInSession);

      expect(
        coordinator.tryClaim(
          'safe_walk_timer',
          sessionId: CheckInExpiryCoordinator.safeWalkSession,
        ),
        isTrue,
      );
      expect(
        coordinator.tryClaim(
          'check_in_service',
          sessionId: CheckInExpiryCoordinator.checkInSession,
        ),
        isTrue,
      );
      expect(
        coordinator.isClaimedFor(CheckInExpiryCoordinator.safeWalkSession),
        isTrue,
      );
      expect(
        coordinator.isClaimedFor(CheckInExpiryCoordinator.checkInSession),
        isTrue,
      );
    });
  });
}
