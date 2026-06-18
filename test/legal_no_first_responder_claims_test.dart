// Doc-contract regression lock (legal equivalent of the export-content test):
// the medical-profile feature was removed, so no user/reviewer-facing legal,
// in-app, published, or store copy may claim the app stores "ilk müdahale" /
// "first-responder" data. Device-health phrasing ("local health and integrity",
// "sağlık ve bütünlük") is intentionally NOT matched here — it is unrelated.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('legal copy has no first-responder/health data-storage claims', () {
    const forbidden = ['ilk müdahale', 'first-responder', 'first responder'];

    final files = <String>[
      'lib/constants/legal_texts.dart',
      'assets/translations/tr-TR.json',
      'assets/translations/en-US.json',
      ...Directory('.gh-pages-publish')
          .listSync()
          .whereType<File>()
          .map((f) => f.path),
      ...Directory('store')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.html') || f.path.endsWith('.md'))
          .map((f) => f.path),
    ];

    test('no forbidden first-responder fragments remain', () {
      final violations = <String>[];
      for (final path in files) {
        final lower = File(path).readAsStringSync().toLowerCase();
        for (final fragment in forbidden) {
          if (lower.contains(fragment)) violations.add('$path :: $fragment');
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
}
