import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'main awaits service locator setup without eagerly starting billing',
    () {
      final source = File('lib/main.dart').readAsStringSync();

      final setupIdx = source.indexOf('await setupServiceLocator();');

      expect(
        setupIdx,
        isNot(-1),
        reason:
            'setupServiceLocator must be awaited before dependent services.',
      );
      expect(
        source,
        isNot(contains('serviceLocator<RevenueCatService>().initialize()')),
        reason:
            'RevenueCat may not configure or contact its service before the '
            'current Terms and KVKK acceptance is known.',
      );
      expect(
        source.contains('setupServiceLocator(),'),
        isFalse,
        reason: 'setupServiceLocator must not be started inside Future.wait.',
      );
    },
  );
}
