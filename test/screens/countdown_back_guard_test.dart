import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system and predictive back cannot dismiss an armed countdown', () {
    final source = File('lib/screens/countdown_screen.dart').readAsStringSync();
    final buildStart = source.indexOf('Widget build(BuildContext context)');

    expect(buildStart, isNot(-1));
    final buildBody = source.substring(buildStart);
    expect(
      buildBody,
      contains('return PopScope('),
      reason:
          'The countdown route must own system/predictive Back instead of '
          'letting Navigator pop the screen and dispose its native alarm.',
    );
    expect(
      buildBody,
      contains('canPop: false'),
      reason:
          'An armed countdown may exit only through its explicit PIN/no-PIN '
          'cancellation paths.',
    );
  });
}
