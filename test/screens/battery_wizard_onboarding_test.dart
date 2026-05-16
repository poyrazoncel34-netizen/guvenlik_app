import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Battery optimization wizard on first launch', () {
    test(
      'home_page should check BatteryOptimizationWizard.shouldShow on init',
      () {
        final source = File('lib/screens/home_page.dart').readAsStringSync();
        expect(
          source,
          contains('BatteryOptimizationWizard.shouldShow'),
          reason:
              'Home page should auto-show battery wizard on first Android launch',
        );
      },
    );
  });
}
