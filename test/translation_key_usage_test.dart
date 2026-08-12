import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ============================================================================
// COVERAGE GATE — kod -> ceviri dosyasi
// ============================================================================
// translations_key_parity_test.dart yalniz tr-TR.json ile en-US.json'i
// BIRBIRIYLE karsilastirir. Iki dosyada da bulunmayan bir anahtar o testten
// gecer: parite bozulmaz, cunku ikisinde de yoktur.
//
// easy_localization eksik bir anahtari calisma zamaninda anahtarin KENDISINE
// cozer. Boyle bir anahtar release'te kullaniciya "panic_button_locked_title"
// seklinde ham metin olarak gorunur; hicbir test kizarmaz, `flutter analyze` de
// gormez. Bu dosya o boslugu kapatir.
// ============================================================================

/// Ic ice yazilmis ceviri agacini easy_localization'in nokta yolu bicimine
/// duzlestirir; duz dosyalarda da dogru calisir.
Map<String, dynamic> _flatten(
  Map<String, dynamic> source, [
  String prefix = '',
]) {
  final flattened = <String, dynamic>{};
  source.forEach((key, value) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      flattened.addAll(_flatten(value, path));
    } else {
      flattened[path] = value;
    }
  });
  return flattened;
}

Set<String> _keysOf(String path) {
  final decoded =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return _flatten(decoded).keys.toSet();
}

List<File> _dartSources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((entity) => entity.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// `'some_key'.tr()` ve `"some_key".tr(namedArgs: ...)` bicimlerini yakalar.
/// Degisken uzerinden yapilan `key.tr()` cagrilari burada gorunmez; onlarin
/// kaynaklari asagidaki ikinci grupta ayrica kapatilir.
final _literalTrCall = RegExp(
  r"""['"]([a-z0-9_][a-z0-9_.]{2,})['"]\s*\.tr\(""",
);

Map<String, String> _keysMissingFrom(Set<String> bundle) {
  final missing = <String, String>{};
  for (final file in _dartSources()) {
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      for (final match in _literalTrCall.allMatches(lines[index])) {
        final key = match.group(1)!;
        if (!bundle.contains(key)) {
          missing.putIfAbsent(key, () => '${file.path}:${index + 1}');
        }
      }
    }
  }
  return missing;
}

String _report(Map<String, String> missing) => missing.entries
    .map((entry) => '  ${entry.key}  <- ${entry.value}')
    .join('\n');

void main() {
  final trKeys = _keysOf('assets/translations/tr-TR.json');
  final enKeys = _keysOf('assets/translations/en-US.json');

  group('every translation key used in lib/ exists in the bundles', () {
    test('tr-TR.json covers every literal .tr() key', () {
      final missing = _keysMissingFrom(trKeys);
      expect(
        missing,
        isEmpty,
        reason:
            'These keys are called with .tr() but are absent from tr-TR.json, '
            'so they would render as raw key text:\n${_report(missing)}',
      );
    });

    test('en-US.json parity reference covers every literal .tr() key', () {
      // en-US.json bu surumde paketlenmiyor ama parite referansidir; bir
      // anahtar orada yoksa parite testi ileride yanlis yesil verir.
      final missing = _keysMissingFrom(enKeys);
      expect(
        missing,
        isEmpty,
        reason:
            'Keys missing from the en-US.json parity reference:\n'
            '${_report(missing)}',
      );
    });
  });

  group('dynamic translation-key providers resolve', () {
    // Bu dosyalar anahtari dondurur, `.tr()` cagrisini baska yerde yapar; yani
    // yukaridaki literal taramasi onlari goremez. Ikisi de panik/paywall
    // yolunda oldugu icin eksik bir anahtar en yuksek siddetli ekranlarda ham
    // metin olarak cikar. Icerikleri neredeyse tamamen anahtar oldugundan
    // "tum snake_case literal bir anahtardir" kurali burada guvenlidir.
    const providers = <String>[
      'lib/core/services/panic_arm_policy.dart',
      'lib/core/constants/feature_access_matrix.dart',
    ];

    // Tirnak icindeki metnin TAMAMI snake_case olmali: `package:flutter/...`
    // gibi import yollari, camelCase reason kodlari ve bosluklu ingilizce
    // etiketler bu sekle uymadigi icin elenir.
    final keyShaped = RegExp(r"""['"]([a-z][a-z0-9]*(?:_[a-z0-9]+)*)['"]""");

    for (final path in providers) {
      test(path, () {
        final source = File(path).readAsStringSync();
        final candidates = keyShaped
            .allMatches(source)
            .map((match) => match.group(1)!)
            .toSet();
        expect(
          candidates,
          isNotEmpty,
          reason: '$path artik anahtar uretmiyorsa bu listeden cikarilmali',
        );
        final missing = candidates.difference(trKeys).toList()..sort();
        expect(
          missing,
          isEmpty,
          reason:
              '$path produces these keys but tr-TR.json does not define them: '
              '${missing.join(', ')}',
        );
      });
    }
  });
}
