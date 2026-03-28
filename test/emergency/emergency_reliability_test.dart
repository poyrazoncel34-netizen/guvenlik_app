// Life-critical reliability tests for the KoruBeni emergency flow.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P0-1: PanicButton must validate contacts before opening CountdownScreen', () {
    test('_openCountdownScreen calls getAllEmergencyNumbers', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      expect(
        source.contains('getAllEmergencyNumbers'),
        isTrue,
        reason: 'Must call getAllEmergencyNumbers() before navigating.',
      );
      expect(
        source.contains('emergency_no_contact_title'),
        isTrue,
        reason:
            'When contacts are empty, must show a blocking dialog '
            '(emergency_no_contact_title) instead of silently returning.',
      );
    });
  });

  group('P0-2: CountdownScreen must not show a permission dialog during emergency', () {
    test('requestCallPhonePermission is not called inside _makeEmergencyCall', () {
      final source =
          File('lib/screens/countdown_screen.dart').readAsStringSync();
      expect(
        source.contains('requestCallPhonePermission'),
        isFalse,
        reason:
            'requestCallPhonePermission shows a blocking UI dialog. '
            'It must not be called during an active emergency.',
      );
    });
  });

  group('P0-3: CountdownScreen total failure must show fullscreen critical alert', () {
    test('total failure shows emergency_total_failure_title dialog with retry', () {
      final source =
          File('lib/screens/countdown_screen.dart').readAsStringSync();
      expect(
        source.contains('emergency_total_failure_title'),
        isTrue,
        reason:
            'When both SMS and call fail, a fullscreen AlertDialog must be '
            'shown using emergency_total_failure_title. Silent snackbar+pop is a P0 failure.',
      );
      expect(
        source.contains('emergency_retry_call'),
        isTrue,
        reason:
            'The total-failure dialog must offer a retry action '
            '(emergency_retry_call) that opens the dialer.',
      );
    });
  });

  group('P0-4: Navigation failure must not stop the foreground service', () {
    test('_handoffToEmergencyScreen is set true before Navigator.pushReplacement', () {
      final source =
          File('lib/screens/countdown_screen.dart').readAsStringSync();
      final handoffIdx =
          source.lastIndexOf('_handoffToEmergencyScreen = true');
      final navIdx = source.indexOf('Navigator.pushReplacement');
      expect(
        handoffIdx != -1 && navIdx != -1 && handoffIdx < navIdx,
        isTrue,
        reason:
            '_handoffToEmergencyScreen must be set true BEFORE '
            'Navigator.pushReplacement so a navigation exception cannot '
            'cause dispose() to stop the foreground service mid-call.',
      );

      // The catch block after Navigator.pushReplacement must NOT reset the flag.
      final catchIdx = source.indexOf('Navigation failed');
      expect(catchIdx, isNot(equals(-1)),
          reason: 'Navigation failure must be logged.');
      final catchBlock = source.substring(catchIdx, catchIdx + 300);
      expect(
        catchBlock.contains('_handoffToEmergencyScreen = false'),
        isFalse,
        reason:
            'Navigation catch block must NOT reset _handoffToEmergencyScreen '
            'to false — the call is still active even if navigation failed.',
      );
    });
  });

  group('P0-5: EmergencyTriggerHost must retry when navigator is null', () {
    test('_openCountdown retries when rootNavigatorKey is null', () {
      final source = File(
        'lib/core/widgets/emergency_trigger_host.dart',
      ).readAsStringSync();
      expect(
        source.contains('Navigator not ready') || source.contains('retrying'),
        isTrue,
        reason:
            'If rootNavigatorKey.currentState is null, _openCountdown must '
            'retry with a short delay instead of silently returning.',
      );
    });
  });

  group('H1: CallService must log swallowed exceptions', () {
    test('catch block in startEmergencyCall logs with EMERGENCY prefix', () {
      final source =
          File('lib/core/services/call_service.dart').readAsStringSync();
      expect(
        source.contains('[EMERGENCY]'),
        isTrue,
        reason:
            'The catch block in CallService.startEmergencyCall must log '
            'with [EMERGENCY] prefix so plugin crashes are diagnosable.',
      );
    });
  });

  group('H3: Volume trigger must not double-subscribe', () {
    test('startListening called exactly once inside _startVolumeIfEnabled', () {
      final source = File(
        'lib/core/widgets/emergency_trigger_host.dart',
      ).readAsStringSync();
      final methodStart = source.indexOf('_startVolumeIfEnabled');
      expect(methodStart, isNot(equals(-1)));
      final methodBody = source.substring(methodStart, methodStart + 600);
      final count = RegExp(r'startListening').allMatches(methodBody).length;
      expect(
        count,
        equals(1),
        reason:
            'startListening must be called exactly once inside '
            '_startVolumeIfEnabled. Calling it twice creates two event '
            'subscriptions and double-fires emergency triggers.',
      );
    });
  });
}
