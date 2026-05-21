import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = Directory.current.path.endsWith('test')
      ? Directory.current.parent.path
      : Directory.current.path;

  final libDir = Directory('$base/lib');

  List<File> dartFiles() {
    return libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  group('No SMS imports in lib/', () {
    test('no file imports sms_service.dart', () {
      final offenders = dartFiles()
          .where(
            (f) =>
                f.readAsStringSync().contains("'sms_service.dart'") ||
                f.readAsStringSync().contains('"sms_service.dart"'),
          )
          .map((f) => f.path)
          .toList();
      expect(
        offenders,
        isEmpty,
        reason: 'These files still import sms_service.dart: $offenders',
      );
    });

    test('no file imports emergency_orchestrator.dart', () {
      final offenders = dartFiles()
          .where(
            (f) => f.readAsStringSync().contains('emergency_orchestrator.dart'),
          )
          .map((f) => f.path)
          .toList();
      expect(
        offenders,
        isEmpty,
        reason:
            'These files still import emergency_orchestrator.dart: $offenders',
      );
    });

    test('no file imports emergency_message_helper.dart', () {
      final offenders = dartFiles()
          .where(
            (f) =>
                f.readAsStringSync().contains('emergency_message_helper.dart'),
          )
          .map((f) => f.path)
          .toList();
      expect(
        offenders,
        isEmpty,
        reason:
            'These files still import emergency_message_helper.dart: $offenders',
      );
    });

    test('EmergencyCallScreen constructor has no smsResult field', () {
      final file = File('$base/lib/screens/emergency_call_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('smsResult'),
        isFalse,
        reason: 'EmergencyCallScreen must not have smsResult field',
      );
    });

    test('check_in_service.dart has no SmsService reference', () {
      final file = File('$base/lib/core/services/check_in_service.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('SmsService'),
        isFalse,
        reason: 'check_in_service must not reference SmsService',
      );
    });

    test('android_intent_service.dart has no composeSms method', () {
      final file = File('$base/lib/core/services/android_intent_service.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('composeSms'),
        isFalse,
        reason: 'AndroidIntentService must not have composeSms',
      );
    });
  });
}
