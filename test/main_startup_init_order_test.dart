import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main awaits service locator setup before service lookups', () {
    final source = File('lib/main.dart').readAsStringSync();

    final setupIdx = source.indexOf('await setupServiceLocator();');
    final revenueCatLookupIdx = source.indexOf(
      'serviceLocator<RevenueCatService>()',
    );

    expect(
      setupIdx,
      isNot(-1),
      reason: 'setupServiceLocator must be awaited before dependent services.',
    );
    expect(
      revenueCatLookupIdx,
      isNot(-1),
      reason: 'RevenueCatService is resolved from GetIt during startup.',
    );
    expect(
      setupIdx < revenueCatLookupIdx,
      isTrue,
      reason:
          'GetIt service lookups during cold start must happen after setup.',
    );
    expect(
      source.contains('setupServiceLocator(),'),
      isFalse,
      reason: 'setupServiceLocator must not be started inside Future.wait.',
    );
  });
}
