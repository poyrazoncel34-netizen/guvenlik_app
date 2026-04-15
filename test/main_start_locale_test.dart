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

  test(
    'main.dart clears a non-Turkish persisted locale on startup',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      // After dil seçimi was removed, any persisted en_US locale must be
      // cleared at startup so startLocale kicks in.
      expect(
        source.contains("prefs.getString('locale')"),
        isTrue,
        reason:
            'main.dart must read the persisted locale to detect en_US leftovers',
      );
      expect(
        source.contains("prefs.remove('locale')"),
        isTrue,
        reason:
            'main.dart must remove the stale non-Turkish locale so the app '
            'restarts in Turkish',
      );
    },
  );
}
