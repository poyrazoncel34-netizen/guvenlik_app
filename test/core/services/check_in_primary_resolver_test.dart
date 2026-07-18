import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/check_in_service.dart';

/// SPEC 0 Karar 1/2: resolve a SINGLE primary target for the check-in /
/// safe-walk escalation. Never synthesize 112; if nothing callable is
/// configured, resolve to empty so NO call is placed (requirement (b)).
void main() {
  const callable = '+905001234567';
  group('CheckInService.resolvePrimaryNumber', () {
    test('returns the primary contact when it is callable', () {
      final result = CheckInService.resolvePrimaryNumber(
        primaryContactPhone: callable,
      );
      expect(result, callable);
    });

    test('does not infer a target when no primary contact exists', () {
      final result = CheckInService.resolvePrimaryNumber(
        primaryContactPhone: null,
      );
      expect(result, isEmpty);
    });

    test('returns empty (NOT 112) when nothing callable is configured', () {
      final result = CheckInService.resolvePrimaryNumber(
        primaryContactPhone: null,
      );
      expect(result, isEmpty);
      expect(result, isNot('112'));
    });

    test(
      'rejects a non-callable primary instead of choosing another contact',
      () {
        final result = CheckInService.resolvePrimaryNumber(
          primaryContactPhone: 'not-a-number',
        );
        expect(result, isEmpty);
      },
    );
  });
}
