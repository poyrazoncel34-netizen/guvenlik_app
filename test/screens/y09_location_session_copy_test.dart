// Y-09 / LR-1: KoruBeni has no "location session" (konum oturumu). Location is
// read only while the Map screen is open, and Panic, Check-In and Safe Walk do
// not use it -- measured, not assumed:
//
//   * source: the only caller of getCurrentLocation() is map_page.dart, and
//     LocationConsentGate (the one gate that may acquire a position) is called
//     from exactly one place, map_page.dart:215, with a header that forbids it
//     on the panic / SOS / check-in path;
//   * runtime: with the location permission REVOKED, Check-In and Safe Walk
//     still arm and Panic still runs (docs/audit/evidence/closure-2026-10-11/
//     lr1-dataflow-api36.md).
//
// Copy the app can show must not describe that nonexistent feature.
//
// LR-1 (2026-10-11) emptied the exemption list below. The consent screen's two
// location strings were the last holdouts; they are now corrected and the
// legal versions bumped, so there is nothing left to exempt. An empty set is
// asserted rather than deleted, so re-adding a key is a visible, deliberate act.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const Set<String> _legalReviewRequired = <String>{};

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

  test('the exemption list is empty -- nothing is still awaiting a rewrite', () {
    expect(_legalReviewRequired, isEmpty);
  });

  test('the legal source of truth no longer names a location session', () {
    final legal = File('lib/constants/legal_texts.dart').readAsStringSync();
    expect(legal.toLowerCase(), isNot(contains('konum oturum')));
    expect(legal.toLowerCase(), isNot(contains('location session')));
  });

  test('the published legal mirrors no longer name a location session', () {
    for (final path in <String>[
      'store/kullanim_sartlari.html',
      'store/aydinlatma_metni.html',
      'store/privacy_policy.html',
    ]) {
      final html = File(path).readAsStringSync().toLowerCase();
      expect(html, isNot(contains('konum oturum')), reason: path);
      expect(html, isNot(contains('location session')), reason: path);
    }
  });

  test('no shown string claims the safety flows use or share location', () {
    // The positive half: the privacy detail the user can actually open must
    // SAY that the safety flows do not use location, not merely avoid saying
    // they do. Without this, deleting the sentence would pass every assertion
    // above.
    final tr = jsonDecode(
      File('assets/translations/tr-TR.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final en = jsonDecode(
      File('assets/translations/en-US.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(tr['detail_privacy_body_3'], contains('konum kullanmaz'));
    expect(en['detail_privacy_body_3'], contains('do not use location'));
    expect(
      tr['legal_consent_location_sub'],
      allOf(contains('Harita'), contains('konum kullanmaz')),
    );
    expect(
      en['legal_consent_location_sub'],
      allOf(contains('Map'), contains('do not use')),
    );
  });
}
