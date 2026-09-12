import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/screens/legal/unified_consent_screen.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:guvenlik_app/widgets/consent_checkbox_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'accessibility_guidelines_test.dart' show pumpLocalized;

class _FaultStore extends InMemorySharedPreferencesStore {
  _FaultStore() : super.withData({'flutter.kvkk_consent_log_v2': '[]'});
  int? failAt;
  int writes = 0;
  bool throws = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (++writes == failAt) {
      if (throws) throw StateError('private phone=555123 PIN=4821');
      return false;
    }
    return super.setValue(type, key, value);
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final throws in [false, true]) {
    for (var boundary = 1; boundary <= 16; boundary++) {
      testWidgets('consent write $boundary rejects=$throws preserves choices and retries', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await EasyLocalization.ensureInitialized();
        PackageInfo.setMockInitialValues(appName: 'Synthetic', packageName: 'test.synthetic', version: '1.0', buildNumber: '1', buildSignature: '');
        final store = _FaultStore();
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = store;
        await serviceLocator.reset();
        final cm = ConsentManager();
        await cm.initialize();
        serviceLocator.registerSingleton<ConsentManager>(cm);
        var accepted = 0;
        await pumpLocalized(tester, UnifiedConsentScreen(onAccepted: () => accepted++));
        await tester.tap(find.text('18 yaşından büyüğüm'));
        await tester.pump();
        final boxes = find.byType(ConsentCheckboxWidget);
        // Actual controls drive the real screen state; only disk is faulted.
        for (final index in [0, 1]) {
          tester.widget<ConsentCheckboxWidget>(boxes.at(index)).onChanged(true);
        }
        await tester.pump();
        store.writes = 0;
        store.failAt = boundary;
        store.throws = throws;
        await tester.runAsync(() async {
          await tester.tap(find.byType(ElevatedButton));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(accepted, 0);
        expect(find.textContaining('Onaylar kaydedilemedi'), findsOneWidget);
        expect(tester.widget<ConsentCheckboxWidget>(boxes.first).value, isTrue);
        expect(tester.takeException(), isNull);
        store.failAt = null;
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.byType(ElevatedButton));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
        expect(accepted, 1);
        await (await SharedPreferences.getInstance()).reload();
        expect((await SharedPreferences.getInstance()).getBool(AppConstants.prefLegalDisclaimerAccepted), isTrue);
        final restarted = ConsentManager();
        await restarted.initialize();
        expect(restarted.getAllConsentStatus().length, 7);
        await tester.pumpWidget(const SizedBox());
        await serviceLocator.reset();
      });
    }
  }
}
