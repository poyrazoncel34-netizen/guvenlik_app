import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Panic route guard', () {
    test('PanicButton only opens countdown from an armed press', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();

      expect(source, contains('final completed ='));
      expect(
        source,
        contains('if (!completed) return;'),
        reason:
            'Release callbacks that never completed three seconds must not '
            'open countdown.',
      );
    });

    test('PanicButton has duplicate countdown navigation guard', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();

      expect(source, contains('_countdownOpening'));
      expect(
        source,
        contains('if (_countdownOpening || !mounted) return;'),
        reason: 'Repeated release events must not stack countdown routes.',
      );
      expect(
        source,
        contains('whenComplete(() => _countdownOpening = false)'),
        reason: 'The route guard must reset when countdown closes.',
      );
    });

    // NOTE: this used to be the ONLY coverage of the quick-access guard, and
    // it asserted only that the guard was reset in a `finally`. That stayed
    // green while the guard was WRITTEN after a ~2.2s await, so two triggers
    // could stack two countdowns (INDEPENDENT_REVIEW_ROUND_2.md R2-02). The
    // behavioural evidence now lives in
    // test/core/widgets/emergency_trigger_duplicate_guard_test.dart, which
    // fires the real trigger twice inside the resolve window; what remains
    // here is the ORDERING contract that test proves.
    test('EmergencyTriggerHost holds the guard across the whole open', () {
      final source = File(
        'lib/core/widgets/emergency_trigger_host.dart',
      ).readAsStringSync();

      final openIdx = source.indexOf('Future<void> _openCountdown()');
      final body = source.substring(openIdx);
      expect(body, contains('try {'));
      expect(body, contains('} finally {'));
      expect(body, contains('_countdownOpen = false;'));
      expect(
        body.indexOf('_countdownOpen = true;'),
        lessThan(body.indexOf('await ')),
        reason:
            'the guard must be acquired before the first suspension point, '
            'not after entitlement resolution',
      );
    });
  });
}
