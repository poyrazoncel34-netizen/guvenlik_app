import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main.dart sets startLocale to tr_TR so app opens in Turkish by default', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source.contains('<<<<<<<'),
      isFalse,
      reason: 'main.dart must not contain git conflict markers',
    );
    expect(
      source.contains("startLocale: const Locale('tr', 'TR')"),
      isTrue,
      reason: 'EasyLocalization must have startLocale set to tr_TR to default to Turkish',
    );
  });
}
