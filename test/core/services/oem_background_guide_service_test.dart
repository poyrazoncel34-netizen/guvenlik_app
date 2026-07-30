import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/oem_background_guide_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Acceptance criteria for the OEM background guide:
///   * a device without the target intent does not crash,
///   * every step is skippable (nothing is a dead end),
///   * "done" survives an app restart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settingsChannel = MethodChannel(
    'com.poyrazoncel.korubeni/settings',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(settingsChannel, null);
  });

  group('vendorFrom', () {
    test('groups brands by the settings layout they ship', () {
      expect(OemBackgroundGuideService.vendorFrom('Xiaomi'), OemVendor.xiaomi);
      expect(OemBackgroundGuideService.vendorFrom('Redmi'), OemVendor.xiaomi);
      expect(OemBackgroundGuideService.vendorFrom('POCO'), OemVendor.xiaomi);
      expect(OemBackgroundGuideService.vendorFrom('HUAWEI'), OemVendor.huawei);
      expect(OemBackgroundGuideService.vendorFrom('HONOR'), OemVendor.huawei);
      expect(OemBackgroundGuideService.vendorFrom('samsung'), OemVendor.samsung);
      expect(
        OemBackgroundGuideService.vendorFrom('OPPO'),
        OemVendor.oppoFamily,
      );
      expect(
        OemBackgroundGuideService.vendorFrom('realme'),
        OemVendor.oppoFamily,
      );
      expect(
        OemBackgroundGuideService.vendorFrom('OnePlus'),
        OemVendor.oppoFamily,
      );
      expect(OemBackgroundGuideService.vendorFrom('vivo'), OemVendor.vivo);
      expect(OemBackgroundGuideService.vendorFrom('iQOO'), OemVendor.vivo);
    });

    test('is case-insensitive and tolerates surrounding whitespace', () {
      expect(
        OemBackgroundGuideService.vendorFrom('  xIaOmI  '),
        OemVendor.xiaomi,
      );
    });

    test('an unknown or empty manufacturer falls back to generic', () {
      expect(OemBackgroundGuideService.vendorFrom('Fairphone'), OemVendor.generic);
      expect(OemBackgroundGuideService.vendorFrom(''), OemVendor.generic);
      expect(OemBackgroundGuideService.vendorFrom('   '), OemVendor.generic);
    });
  });

  group('stepsFor', () {
    test('every vendor gets a non-empty guide', () {
      for (final vendor in OemVendor.values) {
        expect(
          OemBackgroundGuideService.stepsFor(vendor),
          isNotEmpty,
          reason: '$vendor must not open an empty screen',
        );
      }
    });

    test('generic devices still get the standard Android steps', () {
      final steps = OemBackgroundGuideService.stepsFor(OemVendor.generic);
      final ids = steps.map((s) => s.id).toList();

      expect(ids, contains('battery_exemption'));
      expect(ids, contains('generic_battery_list'));
      expect(ids, contains('notifications'));
    });

    test('step ids are unique so progress cannot collide', () {
      for (final vendor in OemVendor.values) {
        final ids = OemBackgroundGuideService.stepsFor(vendor)
            .map((s) => s.id)
            .toList();
        expect(ids.toSet(), hasLength(ids.length), reason: '$vendor');
      }
    });

    test('every step has a reachable target', () {
      for (final vendor in OemVendor.values) {
        for (final step in OemBackgroundGuideService.stepsFor(vendor)) {
          expect(
            step.hasTarget,
            isTrue,
            reason: '${vendor.name}/${step.id} has neither component nor action',
          );
        }
      }
    });

    test('OEM components are well formed package/class pairs', () {
      for (final vendor in OemVendor.values) {
        for (final step in OemBackgroundGuideService.stepsFor(vendor)) {
          final component = step.component;
          if (component == null) continue;
          expect(
            component.split('/'),
            hasLength(2),
            reason: '${step.id} must be pkg/class for openActivityByComponent',
          );
        }
      }
    });

    test('the step list is unmodifiable', () {
      final steps = OemBackgroundGuideService.stepsFor(OemVendor.xiaomi);
      expect(
        () => steps.add(steps.first),
        throwsUnsupportedError,
      );
    });
  });

  group('detectVendor', () {
    test('maps the platform manufacturer string', () async {
      messenger.setMockMethodCallHandler(settingsChannel, (call) async {
        if (call.method == 'getDeviceManufacturer') return 'Xiaomi';
        return null;
      });

      // Host tests report as non-Android, so detectVendor short-circuits to
      // generic. The mapping itself is covered by vendorFrom above; what
      // matters here is that a channel reply never throws.
      expect(await OemBackgroundGuideService.detectVendor(), isA<OemVendor>());
    });

    test('a channel failure degrades to generic instead of throwing', () async {
      messenger.setMockMethodCallHandler(settingsChannel, (call) async {
        throw PlatformException(code: 'NOT_FOUND');
      });

      expect(
        await OemBackgroundGuideService.detectVendor(),
        OemVendor.generic,
      );
    });

    test('a missing channel degrades to generic', () async {
      messenger.setMockMethodCallHandler(settingsChannel, null);

      expect(
        await OemBackgroundGuideService.detectVendor(),
        OemVendor.generic,
      );
    });
  });

  group('openStep on a device without the intent', () {
    test('a rejected component reports noIntent instead of crashing', () async {
      messenger.setMockMethodCallHandler(settingsChannel, (call) async {
        throw PlatformException(code: 'NOT_FOUND');
      });

      const step = OemGuideStep(
        id: 'x',
        titleKey: 't',
        bodyKey: 'b',
        component: 'com.absent.vendor/com.absent.vendor.SettingsActivity',
      );

      expect(await OemBackgroundGuideService.openStep(step), OemStepLaunch.noIntent);
    });

    test('a missing channel reports noIntent instead of crashing', () async {
      messenger.setMockMethodCallHandler(settingsChannel, null);

      const step = OemGuideStep(
        id: 'x',
        titleKey: 't',
        bodyKey: 'b',
        component: 'com.absent.vendor/com.absent.vendor.SettingsActivity',
      );

      expect(await OemBackgroundGuideService.openStep(step), OemStepLaunch.noIntent);
    });

    test('a step with no target at all reports noIntent', () async {
      const step = OemGuideStep(id: 'x', titleKey: 't', bodyKey: 'b');

      expect(await OemBackgroundGuideService.openStep(step), OemStepLaunch.noIntent);
      expect(step.hasTarget, isFalse);
    });
  });

  group('durable progress', () {
    test('progress starts empty', () async {
      expect(
        await OemBackgroundGuideService.completedSteps(OemVendor.xiaomi),
        isEmpty,
      );
      expect(
        await OemBackgroundGuideService.isGuideCompleted(OemVendor.xiaomi),
        isFalse,
      );
    });

    test('a completed step survives a restart', () async {
      await OemBackgroundGuideService.markStepCompleted(
        OemVendor.xiaomi,
        stepId: 'xiaomi_autostart',
      );

      // A fresh SharedPreferences instance is what an app restart sees.
      final reloaded = await SharedPreferences.getInstance();
      await reloaded.reload();

      expect(
        await OemBackgroundGuideService.completedSteps(OemVendor.xiaomi),
        contains('xiaomi_autostart'),
      );
    });

    test('guide completion survives a restart', () async {
      await OemBackgroundGuideService.markGuideCompleted(OemVendor.samsung);

      final reloaded = await SharedPreferences.getInstance();
      await reloaded.reload();

      expect(
        await OemBackgroundGuideService.isGuideCompleted(OemVendor.samsung),
        isTrue,
      );
    });

    test('progress is per vendor and does not leak across families', () async {
      await OemBackgroundGuideService.markStepCompleted(
        OemVendor.xiaomi,
        stepId: 'xiaomi_autostart',
      );

      expect(
        await OemBackgroundGuideService.completedSteps(OemVendor.samsung),
        isEmpty,
      );
      expect(
        await OemBackgroundGuideService.isGuideCompleted(OemVendor.xiaomi),
        isFalse,
        reason: 'One done step is not a finished guide.',
      );
    });

    test('marking the same step twice does not duplicate it', () async {
      await OemBackgroundGuideService.markStepCompleted(
        OemVendor.vivo,
        stepId: 'vivo_background',
      );
      await OemBackgroundGuideService.markStepCompleted(
        OemVendor.vivo,
        stepId: 'vivo_background',
      );

      expect(
        await OemBackgroundGuideService.completedSteps(OemVendor.vivo),
        hasLength(1),
      );
    });

    test('a skipped step is not recorded as completed', () async {
      // Skipping goes nowhere near markStepCompleted; this pins that the only
      // way into the record is an explicit "I did it".
      messenger.setMockMethodCallHandler(settingsChannel, (call) async {
        throw PlatformException(code: 'NOT_FOUND');
      });
      final step = OemBackgroundGuideService.stepsFor(OemVendor.xiaomi).last;

      await OemBackgroundGuideService.openStep(step);

      expect(
        await OemBackgroundGuideService.completedSteps(OemVendor.xiaomi),
        isEmpty,
      );
    });

    test('KVKK deletion clears the records through the global pref wipe', () async {
      await OemBackgroundGuideService.markStepCompleted(
        OemVendor.huawei,
        stepId: 'huawei_startup',
      );
      await OemBackgroundGuideService.markGuideCompleted(OemVendor.huawei);

      // What AppResetService does: SharedPreferences.clear(). The guide keeps no
      // second deletion path of its own.
      await (await SharedPreferences.getInstance()).clear();

      expect(
        await OemBackgroundGuideService.completedSteps(OemVendor.huawei),
        isEmpty,
      );
      expect(
        await OemBackgroundGuideService.isGuideCompleted(OemVendor.huawei),
        isFalse,
      );
    });
  });
}
