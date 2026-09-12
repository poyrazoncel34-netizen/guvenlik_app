import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/onboarding_contact_gate_service.dart';
import 'package:guvenlik_app/screens/onboarding_screen.dart';
import 'package:guvenlik_app/screens/onboarding/onboarding_contact_step.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/contact_service_test_support.dart';
import 'accessibility_guidelines_test.dart'
    show pumpLocalized, assertRealCopyRendered;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(FakeSecureStorage());
    serviceLocator.registerSingleton<LocalDatabaseService>(
      FakeLocalDatabaseService(),
    );
    ContactService.resetCache();
    final consent = ConsentManager();
    await consent.initialize();
    serviceLocator.registerSingleton<ConsentManager>(consent);
    await OnboardingContactGateService.grantContactDataConsent(locale: 'tr');
  });
  tearDown(() async {
    ContactService.resetCache();
    await serviceLocator.reset();
  });
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('real onboarding bounds PIN promise at scale $scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await pumpLocalized(
        tester,
        MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            textScaler: TextScaler.linear(scale),
          ),
          child: OnboardingScreen(onCompleted: () {}),
        ),
      );
      assertRealCopyRendered(tester);
      expect(find.text('KoruBeni yerel PIN ile korunur'), findsOneWidget);
      expect(find.textContaining('telefonun tamamını'), findsOneWidget);
      expect(find.textContaining('zorla açtırılamaz'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('real contact step explains rehearsal limit at scale $scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await pumpLocalized(
        tester,
        MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            textScaler: TextScaler.linear(scale),
          ),
          child: OnboardingContactStep(onGateChanged: (_) {}),
        ),
      );
      assertRealCopyRendered(tester);
      expect(
        find.textContaining('şebekeyi, numaranın erişilebilirliğini'),
        findsOneWidget,
      );
      expect(
        find.textContaining('karşı tarafın yanıtını doğrulamaz'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
