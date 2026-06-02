import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/check_in_service.dart';

/// SPEC 0 Karar 1/2: resolve a SINGLE primary target for the check-in /
/// safe-walk escalation. Never synthesize 112; if nothing callable is
/// configured, resolve to empty so NO call is placed (requirement (b)).
void main() {
  const callable = '+905001234567';
  const otherCallable = '+905009998877';

  group('CheckInService.resolvePrimaryNumber', () {
    test('returns the primary contact when it is callable', () {
      final result = CheckInService.resolvePrimaryNumber(
        primaryContactPhone: callable,
        configuredNumbers: const [otherCallable],
      );
      expect(result, callable);
    });

    test('falls back to the first configured number when no primary contact', () {
      final result = CheckInService.resolvePrimaryNumber(
        primaryContactPhone: null,
        configuredNumbers: const [otherCallable],
      );
      expect(result, otherCallable);
    });

    test('returns empty (NOT 112) when nothing callable is configured', () {
      final result = CheckInService.resolvePrimaryNumber(
        primaryContactPhone: null,
        configuredNumbers: const [],
      );
      expect(result, isEmpty);
      expect(result, isNot('112'));
    });

    test('ignores a non-callable primary and uses a callable configured number', () {
      final result = CheckInService.resolvePrimaryNumber(
        primaryContactPhone: 'not-a-number',
        configuredNumbers: const [otherCallable],
      );
      expect(result, otherCallable);
    });
  });
}
