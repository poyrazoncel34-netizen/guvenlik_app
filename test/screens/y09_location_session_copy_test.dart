// Y-09 (closure audit 2026-10-09): KoruBeni has no "location session" (konum
// oturumu) -- location is read only while the map screen is open, and the
// emergency, Check-in and Safe Walk flows do not use it. Copy the app can
// actually show must not describe that nonexistent feature. The first fix
// rewrote the permission and privacy texts but left the Help FAQ asking
// whether "a location session" drains the battery.
//
// The consent screen's location item still says it: that is legal consent
// wording, changed only through legal review (LEGAL REVIEW REQUIRED) and
// `scripts/bump_legal.sh` -- listed here so it cannot spread silently.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const Set<String> _legalReviewRequired = <String>{
  'legal_consent_location',
  'legal_consent_location_sub',
};

void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.readAsStringSync())
      .join('\n');
  bool shown(String key) =>
      RegExp('[\'"]${RegExp.escape(key)}[\'"]').hasMatch(sources);

  for (final (locale, pattern) in <(String, RegExp)>[
    ('tr-TR', RegExp('konum oturum', caseSensitive: false)),
    ('en-US', RegExp('location[- ](sharing )?session', caseSensitive: false)),
  ]) {
    test('$locale: no copy the app shows describes a location session', () {
      final catalogue =
          jsonDecode(File('assets/translations/$locale.json').readAsStringSync())
              as Map<String, dynamic>;
      final offending = <String>[
        for (final entry in catalogue.entries)
          if (entry.value is String &&
              pattern.hasMatch(entry.value as String) &&
              shown(entry.key) &&
              !_legalReviewRequired.contains(entry.key))
            entry.key,
      ];
      expect(offending, isEmpty);
    });
  }
}
