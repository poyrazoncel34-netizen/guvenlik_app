import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';

/// SPEC §3.2 / §5 ("native-fired dedup" + countdown parity):
/// The check-in / safe-walk escalation must cancel the native AlarmManager
/// backup BEFORE it logs / notifies / places the Dart call — mirroring the
/// proven countdown pattern in countdown_screen.dart (_makeEmergencyCall:
/// "cancel native first, THEN dispatch"). Today the check-in path cancels only
/// at the very end (inside _clearMonitoringState, after CallService), so the
/// dedup window spans the whole escalation body and a native fire mid-flight
/// double-calls the SAME primary number.
///
/// These are source-contract assertions on _triggerEmergency (this method is
/// coupled to ~7 singletons/channels; the repo already verifies it this way —
/// see check_in_primary_only_contract_test.dart). The real Doze race is only
/// confirmable on a physical device.
void main() {
  late String triggerBody;

  setUpAll(() {
    final source = File(
      'lib/core/services/check_in_service.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _triggerEmergency()');
    expect(start, isNot(-1), reason: '_triggerEmergency must exist');
    final end = source.indexOf('static String resolvePrimaryNumber', start);
    triggerBody = source.substring(start, end == -1 ? source.length : end);
  });

  group('Check-in dedup: cancel native backup before the Dart call', () {
    test('native-fired guard short-circuits before any Dart call', () {
      final guardIdx = triggerBody.indexOf('didCheckInAlarmFire');
      final firedBlockIdx = triggerBody.indexOf('if (nativeAlreadyFired)');
      final callIdx = triggerBody.indexOf('CallService.startEmergencyCall');
      expect(guardIdx, isNot(-1), reason: 'dedup guard must be checked');
      expect(firedBlockIdx, isNot(-1));
      expect(callIdx, isNot(-1));
      final returnInBranch = triggerBody.indexOf('return;', firedBlockIdx);
      expect(returnInBranch, isNot(-1));
      expect(
        returnInBranch < callIdx,
        isTrue,
        reason:
            'native-fired path must return before CallService (no 2nd call)',
      );
    });

    test('cancelCheckIn is invoked BEFORE CallService.startEmergencyCall', () {
      final cancelIdx = triggerBody.indexOf('cancelCheckIn');
      final callIdx = triggerBody.indexOf('CallService.startEmergencyCall');
      expect(
        cancelIdx,
        isNot(-1),
        reason:
            'native backup must be cancelled inside _triggerEmergency, not only '
            'later in _clearMonitoringState',
      );
      expect(callIdx, isNot(-1));
      expect(
        cancelIdx < callIdx,
        isTrue,
        reason:
            'cancel must precede the call so the dedup window is one '
            'round-trip, not the whole escalation body',
      );
    });

    test('cancelCheckIn precedes log / haptic / notification', () {
      final cancelIdx = triggerBody.indexOf('cancelCheckIn');
      final logIdx = triggerBody.indexOf('ActivityService.logEvent');
      expect(cancelIdx, isNot(-1));
      expect(logIdx, isNot(-1));
      expect(
        cancelIdx < logIdx,
        isTrue,
        reason: 'cancel must happen before logging begins (countdown parity)',
      );
    });

    test(
      'the pre-call cancel is wrapped in a dedicated try/catch (fail-safe)',
      () {
        final cancelIdx = triggerBody.indexOf('cancelCheckIn');
        final logIdx = triggerBody.indexOf('ActivityService.logEvent');
        expect(cancelIdx, isNot(-1));
        final tryBeforeCancel = triggerBody.lastIndexOf('try {', cancelIdx);
        expect(
          tryBeforeCancel,
          isNot(-1),
          reason: 'cancel must sit inside a try block',
        );
        final catchAfterCancel = triggerBody.indexOf(
          'on Exception catch',
          cancelIdx,
        );
        expect(
          catchAfterCancel,
          isNot(-1),
          reason: 'a cancel failure must be caught so it never blocks dispatch',
        );
        expect(
          catchAfterCancel < logIdx,
          isTrue,
          reason:
              'cancel must have its OWN tight try/catch, not rely on the '
              'outer one (which would skip the call on a cancel failure)',
        );
      },
    );
  });

  group('Fail-safe guard: cancelCheckIn cannot throw into the caller', () {
    const channel = MethodChannel(
      'com.poyrazoncel.korubeni/emergency_platform',
    );

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'cancelCheckIn completes (does not throw) when native side throws',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'cancelCheckIn') {
                throw MissingPluginException('cancelCheckIn not implemented');
              }
              return null;
            });

        await expectLater(
          EmergencyPlatformService.instance.cancelCheckIn(),
          completes,
        );
      },
    );
  });
}
