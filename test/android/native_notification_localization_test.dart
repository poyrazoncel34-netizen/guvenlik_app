import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('native notification localization', () {
    const localizationDictionary =
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/NativeNotificationText.kt';

    test('Kotlin notification channels use the canonical channel IDs', () {
      final helper = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyNotificationHelper.kt',
      ).readAsStringSync();

      expect(helper, contains('const val CHANNEL_ALERTS = "emergency_alerts"'));
      expect(helper, contains('const val CHANNEL_SERVICE = "service_status"'));
      expect(
        helper,
        contains('const val CHANNEL_GENERAL = "general_notifications"'),
      );

      const oldIds = [
        'korubeni_alerts_high',
        'korubeni_service_low',
        'korubeni_general_default',
      ];
      for (final id in oldIds) {
        expect(helper, isNot(contains(id)));
      }
    });

    test('Dart foreground service uses service_status channel', () {
      final foreground = File(
        'lib/core/services/foreground_service.dart',
      ).readAsStringSync();

      expect(
        foreground,
        contains(
          "const String kForegroundChannelId = kServiceStatusChannelId;",
        ),
      );
      expect(foreground, isNot(contains('korubeni_foreground')));
      expect(foreground, contains("'notification_channel_service_name'"));
      expect(foreground, contains("'notification_channel_service_desc'"));
    });

    test('native dictionary has Turkish, English, and safe fallbacks', () {
      final dictionary = File(localizationDictionary).readAsStringSync();

      expect(dictionary, contains('FlutterSharedPreferences'));
      // Audit F8: TR-locked product — persisted locale wins, otherwise TR.
      // The system-locale step and the EN default are intentionally gone.
      expect(dictionary, contains('?: Language.TR'));
      expect(dictionary, isNot(contains('?: Language.EN')));
      expect(dictionary, isNot(contains('Locale.getDefault')));
      expect(dictionary, contains('Emergency Alerts'));
      expect(dictionary, contains('Acil Bildirimler'));
      expect(dictionary, contains('Please confirm that you are safe.'));
      expect(dictionary, contains('Lütfen güvende olduğunuzu onaylayın.'));
      expect(dictionary, contains('Emergency triggered'));
      expect(dictionary, contains('Acil durum tetiklendi'));
    });

    test(
      'hardcoded Turkish notification phrases stay inside native dictionary',
      () {
        const forbiddenOutsideDictionary = [
          'Acil Durum Bildirimleri',
          'Check-in ve acil durum uyarilari',
          'Check-in suresi doldu',
          'Lutfen guvende oldugunuzu onaylayin.',
          'Check-in acil durumu',
          'Guvenli yuruyus zamani doldu.',
          'Acil Bildirimler',
          'Kritik güvenlik ve check-in bildirimleri',
          'Servis Durumu',
          'Genel Bildirimler',
          'Check-in süresi doldu',
          'Güvenli yürüyüş süresi doldu',
          'Acil durum tetiklendi',
        ];

        final kotlinFiles =
            Directory('android/app/src/main/kotlin/com/poyrazoncel/korubeni')
                .listSync(recursive: true)
                .whereType<File>()
                .where((file) => file.path.endsWith('.kt'))
                .where((file) => file.path != localizationDictionary);

        final violations = <String>[];
        for (final file in kotlinFiles) {
          final source = file.readAsStringSync();
          for (final phrase in forbiddenOutsideDictionary) {
            if (source.contains(phrase)) {
              violations.add('${file.path}:$phrase');
            }
          }
        }

        expect(violations, isEmpty);
      },
    );
  });
}
