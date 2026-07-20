import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main awaits fail-closed critical bootstrap without eager billing', () {
    final source = File('lib/main.dart').readAsStringSync();

    final bootstrapIdx = source.indexOf('AppBootstrapService.production()');

    expect(
      bootstrapIdx,
      isNot(-1),
      reason: 'Critical bootstrap must complete before runApp.',
    );
    expect(source, contains('if (!criticalBootstrap.isReady)'));
    expect(source, contains('ErrorWidget.builder('));
    expect(
      source,
      isNot(contains('serviceLocator<RevenueCatService>().initialize()')),
      reason:
          'RevenueCat may not configure or contact its service before the '
          'current Terms and KVKK acceptance is known.',
    );
  });
}
