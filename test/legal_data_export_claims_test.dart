import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('data export never mislabels KVKK Article 11 as portability', () {
    final paths = <String>[
      'lib/core/services/user_data_export_service.dart',
      'lib/screens/settings_legal/data_export_screen.dart',
      'lib/services/consent_manager.dart',
      'assets/translations/tr-TR.json',
      'assets/translations/en-US.json',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync().toLowerCase();
      expect(source, isNot(contains('veri portabilitesi')), reason: path);
      expect(source, isNot(contains('data portability')), reason: path);
      expect(source, isNot(contains('kvkk madde 11/ğ')), reason: path);
      expect(source, isNot(contains('kvkk article 11/ğ')), reason: path);
      expect(source, isNot(contains('kvkk article 11/f')), reason: path);
    }
  });

  test('copy explains that it is local and not a statutory request', () {
    final tr =
        jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
            as Map<String, dynamic>;
    final en =
        jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(
      tr['data_export_kvkk_desc'],
      contains('hukuki başvurunun yerine geçmez'),
    );
    expect(
      en['data_export_kvkk_desc'],
      contains('does not replace a legal request'),
    );
  });
}
