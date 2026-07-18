import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('battery exemption has one native authority and no plugin bypass', () {
    final kotlinFiles = Directory('android/app/src/main/kotlin')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.kt'));
    final directRequestOwners = <String>[];
    for (final file in kotlinFiles) {
      final source = file.readAsStringSync();
      if (source.contains('ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS')) {
        directRequestOwners.add(file.path);
      }
    }

    expect(
      directRequestOwners,
      equals([
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/'
            'EmergencyPlatformHandler.kt',
      ]),
      reason:
          'Only the emergency platform authority may open the direct exemption request.',
    );

    final mainActivity = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt',
    ).readAsStringSync();
    expect(mainActivity, isNot(contains('DozeModeHandler')));
    expect(
      mainActivity,
      isNot(contains('ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS')),
    );

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('optimize_battery:')));

    final dartSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final pluginBypasses = <String>[];
    for (final file in dartSources) {
      final source = file.readAsStringSync();
      if (source.contains('package:optimize_battery/') ||
          source.contains('OptimizeBattery.')) {
        pluginBypasses.add(file.path);
      }
    }
    expect(pluginBypasses, isEmpty);
  });

  test('direct request and generic settings are distinct platform actions', () {
    final native = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/'
      'EmergencyPlatformHandler.kt',
    ).readAsStringSync();
    final dart = File(
      'lib/core/services/emergency_platform_service.dart',
    ).readAsStringSync();

    expect(native, contains('"requestBatteryOptimizationExemption"'));
    expect(native, contains('"openBatteryOptimizationSettings"'));
    expect(
      native,
      contains('Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
    );
    expect(
      native,
      contains('Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS'),
    );
    expect(
      dart,
      contains('Future<bool> requestBatteryOptimizationExemption()'),
    );
    expect(dart, contains('Future<bool> openBatteryOptimizationSettings()'));
  });
}
