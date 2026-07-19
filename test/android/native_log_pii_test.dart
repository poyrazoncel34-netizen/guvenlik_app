import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _productionKotlinSources() => Directory('android/app/src/main')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.kt'))
    .toList(growable: false);

void main() {
  test('production Kotlin never logs or returns raw exception messages', () {
    final sources = _productionKotlinSources();
    expect(sources, isNotEmpty);

    for (final file in sources) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('.message')),
        reason:
            '${file.path}: Android exception messages may embed tel: URIs, '
            'contact data, component arguments, or other user-controlled '
            'values.',
      );
      expect(
        RegExp(
          r'(?:android\.util\.)?Log\.[a-z]+\([^\n]*,\s*'
          r'(?:e|error|exception|throwable|cause)\w*\s*\)',
        ).hasMatch(source),
        isFalse,
        reason:
            '${file.path}: logging a Throwable also emits its raw message; '
            'native release logs must use bounded static event codes.',
      );
      expect(
        source,
        isNot(contains('Log.getStackTraceString')),
        reason:
            '${file.path}: native stack serialization can persist sensitive '
            'exception messages.',
      );
    }
  });

  test('dial and contact failures use bounded non-PII event codes', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt',
    ).readAsStringSync();

    expect(source, contains('INTENT_LAUNCH_NOT_FOUND'));
    expect(source, contains('CONTACT_PICK_QUERY_FAILED'));
    expect(source, contains('ANDROID_INTENTS_ERROR'));
  });
}
