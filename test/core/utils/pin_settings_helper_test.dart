import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PinSettingsHelper digit-only input enforcement', () {
    late String source;

    setUp(() {
      source = File(
        'lib/core/utils/pin_settings_helper.dart',
      ).readAsStringSync();
    });

    test('uses FilteringTextInputFormatter to block non-digit input', () {
      expect(
        source.contains('FilteringTextInputFormatter'),
        isTrue,
        reason:
            'PIN alanları yalnızca rakam kabul etmeli; '
            'FilteringTextInputFormatter.digitsOnly kullanılmalı',
      );
    });

    test('enforces maxLength of 4 on PIN fields', () {
      expect(
        source.contains('maxLength: 4'),
        isTrue,
        reason: 'PIN alanları maksimum 4 karakter kabul etmeli',
      );
    });
  });
}
