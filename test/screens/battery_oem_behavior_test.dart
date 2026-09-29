import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/oem_background_guide_service.dart';
import 'package:guvenlik_app/screens/battery_optimization_wizard.dart';
import 'package:guvenlik_app/screens/oem_background_guide_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

Future<void> _pumpLauncher(
  WidgetTester tester, {
  Future<bool> Function()? optimizationStatusLoader,
}) async {
  await pumpLocalized(
    tester,
    Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BatteryOptimizationWizard(
              optimizationStatusLoader: optimizationStatusLoader,
            ),
          ),
        ),
        child: const Text('Pil sihirbazını aç'),
      ),
    ),
  );
  await tester.tap(find.text('Pil sihirbazını aç'));
  await tester.pumpAndSettle();
  expect(find.byType(BatteryOptimizationWizard), findsOneWidget);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets(
    'PIL-02/OEM-03/OEM-04: wizard opens real OEM guide, records a step and finishes',
    (tester) async {
      await _pumpLauncher(tester);

      await _tapVisible(tester, find.text('Cihazıma Özel Adımlar'));
      expect(find.byType(OemBackgroundGuideScreen), findsOneWidget);
      expect(find.text('0 / 3 adım tamamlandı'), findsOneWidget);

      await _tapVisible(tester, find.text('Yaptım').first);
      expect(
        await OemBackgroundGuideService.completedSteps(OemVendor.generic),
        contains('battery_exemption'),
      );
      expect(find.text('Yaptım'), findsNWidgets(2));

      await _tapVisible(tester, find.text('Tamamlandı'));
      expect(find.byType(OemBackgroundGuideScreen), findsNothing);
      expect(find.byType(BatteryOptimizationWizard), findsOneWidget);
      expect(
        await OemBackgroundGuideService.isGuideCompleted(OemVendor.generic),
        isTrue,
      );
    },
  );

  testWidgets('PIL-04: skip persists dismissal/snooze and pops the wizard', (
    tester,
  ) async {
    await _pumpLauncher(tester);

    await _tapVisible(tester, find.text('Şimdilik Atla'));

    expect(find.byType(BatteryOptimizationWizard), findsNothing);
    expect(find.text('Pil sihirbazını aç'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('battery_optimization_wizard_dismiss_count'), 1);
    expect(
      prefs.getInt('battery_optimization_wizard_snooze_until_ms'),
      greaterThan(DateTime.now().millisecondsSinceEpoch),
    );
  });

  testWidgets('PIL-05: already-exempt done action marks seen and pops', (
    tester,
  ) async {
    await _pumpLauncher(tester, optimizationStatusLoader: () async => true);

    await _tapVisible(tester, find.text('Tamamlandı'));

    expect(find.byType(BatteryOptimizationWizard), findsNothing);
    expect(find.text('Pil sihirbazını aç'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'battery_optimization_wizard_seen',
      ),
      isTrue,
    );
  });
}
