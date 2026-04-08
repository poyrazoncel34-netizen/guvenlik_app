import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base =
      Directory.current.path.endsWith('test')
          ? Directory.current.parent.path
          : Directory.current.path;

  final ktBase =
      '$base/android/app/src/main/kotlin/com/poyrazoncel/korubeni';

  group('Call-only executor', () {
    test('EmergencyExecutor.kt must NOT reference SmsSender', () {
      final file = File('$ktBase/emergency/EmergencyExecutor.kt');
      expect(file.existsSync(), isTrue, reason: 'EmergencyExecutor.kt must exist');
      final content = file.readAsStringSync();
      expect(content.contains('SmsSender'), isFalse,
          reason: 'EmergencyExecutor must not reference SmsSender');
    });

    test('EmergencyPlatformHandler.kt must NOT have sendSms case', () {
      final file = File('$ktBase/emergency/EmergencyPlatformHandler.kt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('"sendSms"'), isFalse,
          reason: 'EmergencyPlatformHandler must not have sendSms case');
    });

    test('EmergencyPlatformHandler.kt must NOT have triggerEmergency case', () {
      final file = File('$ktBase/emergency/EmergencyPlatformHandler.kt');
      final content = file.readAsStringSync();
      expect(content.contains('"triggerEmergency"'), isFalse,
          reason: 'EmergencyPlatformHandler must not have triggerEmergency case');
    });

    test('main AndroidManifest.xml must NOT have smsto scheme', () {
      final file =
          File('$base/android/app/src/main/AndroidManifest.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('smsto'), isFalse,
          reason: 'AndroidManifest must not include smsto intent query');
    });

    test('full/AndroidManifest.xml must NOT exist', () {
      final file =
          File('$base/android/app/src/full/AndroidManifest.xml');
      expect(file.existsSync(), isFalse,
          reason: 'full flavor manifest must be deleted (no SEND_SMS)');
    });

    test('SmsSender.kt must NOT exist', () {
      final file = File('$ktBase/emergency/SmsSender.kt');
      expect(file.existsSync(), isFalse,
          reason: 'SmsSender.kt must be deleted');
    });

    test('SmsStatusReceiver.kt must NOT exist', () {
      final file = File('$ktBase/emergency/SmsStatusReceiver.kt');
      expect(file.existsSync(), isFalse,
          reason: 'SmsStatusReceiver.kt must be deleted');
    });

    test('CountdownAlarmScheduler.kt must NOT reference recipients or message', () {
      final file =
          File('$ktBase/emergency/CountdownAlarmScheduler.kt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('KEY_COUNTDOWN_RECIPIENTS'), isFalse,
          reason: 'No recipients key in CountdownAlarmScheduler');
      expect(content.contains('KEY_COUNTDOWN_MESSAGE'), isFalse,
          reason: 'No message key in CountdownAlarmScheduler');
    });

    test('MainActivity.kt must NOT have composeSms method', () {
      final file = File('$base/android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('composeSms'), isFalse,
          reason: 'MainActivity must not have composeSms');
      expect(content.contains('smsto'), isFalse,
          reason: 'MainActivity must not reference smsto scheme');
    });
  });
}
