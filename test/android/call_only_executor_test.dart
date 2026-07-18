import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = Directory.current.path.endsWith('test')
      ? Directory.current.parent.path
      : Directory.current.path;

  final ktBase = '$base/android/app/src/main/kotlin/com/poyrazoncel/korubeni';

  group('Call-only executor', () {
    test('target validator is side-effect free and has no SMS surface', () {
      final file = File('$ktBase/emergency/EmergencyTargetValidator.kt');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'The single native target validator must exist',
      );
      final content = file.readAsStringSync();
      expect(content, isNot(contains('SmsSender')));
      expect(content, isNot(contains('TelecomManager')));
      expect(content, isNot(contains('startActivity')));
      expect(content, isNot(contains('Intent.ACTION_')));
    });

    test('EmergencyPlatformHandler.kt must NOT have sendSms case', () {
      final file = File('$ktBase/emergency/EmergencyPlatformHandler.kt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('"sendSms"'),
        isFalse,
        reason: 'EmergencyPlatformHandler must not have sendSms case',
      );
    });

    test('EmergencyPlatformHandler.kt must NOT have triggerEmergency case', () {
      final file = File('$ktBase/emergency/EmergencyPlatformHandler.kt');
      final content = file.readAsStringSync();
      expect(
        content.contains('"triggerEmergency"'),
        isFalse,
        reason: 'EmergencyPlatformHandler must not have triggerEmergency case',
      );
    });

    test('main AndroidManifest.xml must NOT have smsto scheme', () {
      final file = File('$base/android/app/src/main/AndroidManifest.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('smsto'),
        isFalse,
        reason: 'AndroidManifest must not include smsto intent query',
      );
    });

    test('full/AndroidManifest.xml must NOT exist', () {
      final file = File('$base/android/app/src/full/AndroidManifest.xml');
      expect(
        file.existsSync(),
        isFalse,
        reason: 'full flavor manifest must be deleted (no SEND_SMS)',
      );
    });

    test('SmsSender.kt must NOT exist', () {
      final file = File('$ktBase/emergency/SmsSender.kt');
      expect(
        file.existsSync(),
        isFalse,
        reason: 'SmsSender.kt must be deleted',
      );
    });

    test('SmsStatusReceiver.kt must NOT exist', () {
      final file = File('$ktBase/emergency/SmsStatusReceiver.kt');
      expect(
        file.existsSync(),
        isFalse,
        reason: 'SmsStatusReceiver.kt must be deleted',
      );
    });

    test('typed native coordinator never falls back to / synthesizes 112', () {
      final validator = File(
        '$ktBase/emergency/EmergencyTargetValidator.kt',
      ).readAsStringSync();
      final runtime = File(
        '$ktBase/emergency/AndroidEmergencySessionRuntime.kt',
      ).readAsStringSync();
      final coordinator = File(
        '$ktBase/emergency/EmergencySessionCoordinator.kt',
      ).readAsStringSync();
      final content = '$validator\n$runtime\n$coordinator';
      // No 112 literal in any callable form, no coercion helper, no
      // short-code allow-list. On total dispatch failure it reports failure.
      expect(content, isNot(contains('"112"')));
      expect(content, isNot(contains('ifEmpty { "112" }')));
      expect(content, isNot(contains('normalizeEmergencyTarget')));
      expect(content, isNot(contains('OFFICIAL_EMERGENCY_SHORT_CODES')));
      expect(runtime, contains('telecom.placeCall('));
      expect(runtime, isNot(contains('Intent.ACTION_CALL')));
      expect(runtime, isNot(contains('startActivity(')));
      expect(coordinator, contains('LifecycleState.REQUEST_FAILED'));
    });

    test(
      'Telecom request requires CALL_PHONE and raw ACTION_CALL is absent',
      () {
        final file = File(
          '$ktBase/emergency/AndroidEmergencySessionRuntime.kt',
        );
        final content = file.readAsStringSync();
        final permissionCheck = content.indexOf(
          'Manifest.permission.CALL_PHONE',
        );
        final placeCall = content.indexOf('telecom.placeCall(');

        expect(permissionCheck, isNot(-1));
        expect(placeCall, isNot(-1));
        expect(permissionCheck < placeCall, isTrue);
        expect(content, isNot(contains('Intent.ACTION_CALL')));
      },
    );

    test('legacy scheduler and executor authorities must not compile', () {
      for (final fileName in [
        'CountdownAlarmScheduler.kt',
        'CheckInScheduler.kt',
        'EmergencyExecutor.kt',
      ]) {
        expect(
          File('$ktBase/emergency/$fileName').existsSync(),
          isFalse,
          reason: '$fileName would reintroduce a second safety authority',
        );
      }
    });

    test('MainActivity.kt must NOT have composeSms method', () {
      final file = File(
        '$base/android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('composeSms'),
        isFalse,
        reason: 'MainActivity must not have composeSms',
      );
      expect(
        content.contains('smsto'),
        isFalse,
        reason: 'MainActivity must not reference smsto scheme',
      );
    });
  });
}
