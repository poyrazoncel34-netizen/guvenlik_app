import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TR and EN translation files have identical top-level keys', () {
    final tr =
        jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
            as Map<String, dynamic>;
    final en =
        jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
            as Map<String, dynamic>;

    final trOnly = tr.keys.toSet().difference(en.keys.toSet()).toList()..sort();
    final enOnly = en.keys.toSet().difference(tr.keys.toSet()).toList()..sort();

    expect(
      trOnly,
      isEmpty,
      reason: 'Keys present only in tr-TR.json: ${trOnly.join(', ')}',
    );
    expect(
      enOnly,
      isEmpty,
      reason: 'Keys present only in en-US.json: ${enOnly.join(', ')}',
    );
    expect(tr.length, en.length);
  });
}
