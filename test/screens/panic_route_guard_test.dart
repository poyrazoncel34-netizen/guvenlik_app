import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Panic route guard', () {
    test('PanicButton only opens countdown from an armed press', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();

      expect(source, contains('final wasArmed = _isArmed;'));
      expect(
        source,
        contains('if (!wasArmed) return;'),
        reason: 'Release callbacks that never armed must not open countdown.',
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

    test('EmergencyTriggerHost resets route guard in finally', () {
      final source = File(
        'lib/core/widgets/emergency_trigger_host.dart',
      ).readAsStringSync();

      final openIdx = source.indexOf('Future<void> _openCountdown()');
      final body = source.substring(openIdx);
      expect(body, contains('try {'));
      expect(body, contains('} finally {'));
      expect(body, contains('_countdownOpen = false;'));
    });
  });
}
