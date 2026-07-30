// Source contract for the OEM background guide wiring. Behaviour lives in
// test/core/services/oem_background_guide_service_test.dart; this pins that the
// screen delegates to it, that the guide is reachable, and that reaching the OEM
// screens cost no new permission.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String screen;
  late String service;
  late String mainActivity;
  late String manifest;
  late String wizard;
  late String settings;

  setUpAll(() {
    screen = File(
      'lib/screens/oem_background_guide_screen.dart',
    ).readAsStringSync();
    service = File(
      'lib/core/services/oem_background_guide_service.dart',
    ).readAsStringSync();
    mainActivity = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt',
    ).readAsStringSync();
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    wizard = File(
      'lib/screens/battery_optimization_wizard.dart',
    ).readAsStringSync();
    settings = File('lib/screens/settings_page.dart').readAsStringSync();
  });

  group('the guide costs no new permission and no new dependency', () {
    test('manufacturer detection rides the existing settings channel', () {
      expect(mainActivity, contains('"getDeviceManufacturer"'));
      expect(mainActivity, contains('Build.MANUFACTURER'));
      expect(
        service,
        contains('com.poyrazoncel.korubeni/settings'),
        reason: 'Reuse the existing channel; no second channel for one value.',
      );
    });

    test('no device_info_plus dependency was added', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec.contains('device_info_plus'),
        isFalse,
        reason: 'Build.MANUFACTURER needs no package and no permission.',
      );
    });

    test('the manifest permission set is unchanged', () {
      // Adding a permission is a release/policy event. Reading
      // Build.MANUFACTURER and launching a settings Activity need none.
      final permissions = RegExp(r'<uses-permission[^>]*android:name="([^"]+)"')
          .allMatches(manifest)
          .map((m) => m.group(1))
          .toSet();

      expect(permissions, {
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.ACCESS_NETWORK_STATE',
        'android.permission.INTERNET',
        'com.android.vending.BILLING',
        'android.permission.READ_CONTACTS',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.VIBRATE',
        'android.permission.CALL_PHONE',
        'android.permission.WAKE_LOCK',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.SCHEDULE_EXACT_ALARM',
        'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      });
      // READ_CONTACTS is present only as a tools:node="remove" marker.
      expect(manifest, contains('tools:node="remove"'));
    });

    test('per-step intents reuse openActivityByComponent', () {
      expect(mainActivity, contains('"openActivityByComponent"'));
      expect(service, contains("'openActivityByComponent'"));
    });
  });

  group('the screen only presents', () {
    test('vendor, steps and progress all come from the service', () {
      expect(screen, contains('OemBackgroundGuideService.detectVendor()'));
      expect(screen, contains('OemBackgroundGuideService.stepsFor(vendor)'));
      expect(screen, contains('OemBackgroundGuideService.completedSteps('));
      expect(screen, contains('OemBackgroundGuideService.openStep(step)'));
      expect(screen, contains('OemBackgroundGuideService.markStepCompleted('));
      expect(screen, contains('OemBackgroundGuideService.markGuideCompleted('));
    });

    test('the screen holds no vendor mapping of its own', () {
      for (final brand in ['xiaomi', 'huawei', 'samsung', 'oppo', 'vivo']) {
        expect(
          screen.toLowerCase().contains("contains('$brand')"),
          isFalse,
          reason: 'Vendor mapping belongs in the service, not the screen.',
        );
      }
      expect(
        screen.contains('MethodChannel('),
        isFalse,
        reason: 'The screen must not open a channel of its own.',
      );
    });

    test('a step whose screen is absent shows text instead of failing', () {
      expect(screen, contains('OemStepLaunch.noIntent'));
      expect(screen, contains("'oem_guide_step_unavailable'"));
    });

    test('the open action is only offered when a target exists', () {
      expect(screen, contains('if (step.hasTarget)'));
    });

    test('checks mounted after every await before touching state', () {
      // Async gaps in a screen that launches external Activities: the user can
      // leave at any moment.
      final awaits = screen.split('await ').length - 1;
      final guards = screen.split('if (!mounted)').length - 1;
      expect(
        guards,
        greaterThanOrEqualTo(4),
        reason: 'Found $awaits awaits but only $guards mounted guards.',
      );
    });
  });

  group('the guide is reachable and re-openable', () {
    test('settings has a permanent entry', () {
      expect(settings, contains('OemBackgroundGuideScreen()'));
      expect(settings, contains('"settings_oem_guide_title".tr()'));
    });

    test('the existing battery wizard hands off to it', () {
      expect(wizard, contains('OemBackgroundGuideScreen()'));
      expect(wizard, contains("'battery_wizard_oem_btn'"));
    });
  });

  group('copy makes no reliability guarantee', () {
    test('the footer states that background behaviour is not guaranteed', () {
      expect(screen, contains("'oem_guide_no_guarantee'"));
    });

    test('the dead manufacturer cache is finally populated', () {
      // isAggressiveManufacturer() read a cache that nothing ever wrote, so it
      // was permanently false.
      expect(service, contains('BatteryOptimizationService.cacheManufacturer'));
    });
  });
}
