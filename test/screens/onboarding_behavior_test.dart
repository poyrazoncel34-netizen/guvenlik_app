import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/screens/onboarding_screen.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/contact_service_test_support.dart';
import 'accessibility_guidelines_test.dart' show pumpLocalized;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(FakeSecureStorage());
    serviceLocator.registerSingleton<LocalDatabaseService>(
      FakeLocalDatabaseService(),
    );
    ContactService.resetCache();
    PackageInfo.setMockInitialValues(
      appName: 'KoruBeni',
      packageName: 'test.korubeni',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    final consentManager = ConsentManager();
    await consentManager.initialize();
    serviceLocator.registerSingleton<ConsentManager>(consentManager);
  });

  Future<void> skipToContact(WidgetTester tester) async {
    await tester.tap(find.text('Atla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (var round = 0; round < 15; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
      if (find.text('Acil kişinizi ekleyin').evaluate().isNotEmpty) break;
    }
  }

  Future<void> openFilledContactForm(WidgetTester tester) async {
    await tester.runAsync(
      () => serviceLocator<ConsentManager>().grantConsent(
        ConsentRecord.typeEmergencyContacts,
        locale: 'tr',
      ),
    );
    await pumpLocalized(tester, const OnboardingScreen());
    await skipToContact(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Zeynep');
    await tester.enterText(fields.at(1), '+905551112233');
    final save = find.text('Kişiyi kaydet');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Kişi Ekleme Onayı'), findsOneWidget);
  }
  tearDown(() async {
    ContactService.resetCache();
    await serviceLocator.reset();
  });

  testWidgets('ONB-03 next advances the real production PageView', (
    tester,
  ) async {
    await pumpLocalized(tester, const OnboardingScreen());
    expect(find.text('KoruBeni yerel PIN ile korunur'), findsOneWidget);

    await tester.tap(find.text('İleri'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tek kişi. Senin seçtiğin.'), findsOneWidget);
    expect(find.text('KoruBeni yerel PIN ile korunur'), findsNothing);
  });

  testWidgets('ONB-01/ONB-04 skip lands on contact gate without completing', (
    tester,
  ) async {
    var completed = false;
    await pumpLocalized(
      tester,
      OnboardingScreen(onCompleted: () => completed = true),
    );

    await skipToContact(tester);

    expect(find.text('Acil kişinizi ekleyin'), findsWidgets);
    expect(find.text('Atla'), findsNothing);
    final start = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Başla'),
    );
    expect(start.onPressed, isNull);
    expect(
      find.text('Devam etmek için aranabilir bir acil kişi gerekir.'),
      findsOneWidget,
    );
    expect(completed, isFalse);
  });

  testWidgets('ONB-06 consent action enables the real contact form', (
    tester,
  ) async {
    await pumpLocalized(tester, const OnboardingScreen());
    await skipToContact(tester);
    expect(find.text('Onay veriyorum'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, false);

    final grant = find.text('Onay veriyorum');
    await tester.ensureVisible(grant);
    await tester.tap(grant);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('Onay veriyorum'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, true);
  });

  testWidgets('ONB-05 callable primary contact enables and completes onboarding', (
    tester,
  ) async {
    await tester.runAsync(
      () => ContactService.savePrimaryEmergencyContact(
        name: 'Ayşe',
        phone: '+905001234567',
      ),
    );
    var completed = false;
    await pumpLocalized(
      tester,
      OnboardingScreen(onCompleted: () => completed = true),
    );
    await skipToContact(tester);
    final start = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Başla'),
    );
    expect(start.onPressed, isNotNull);

    await tester.tap(find.text('Başla'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(completed, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        AppConstants.prefOnboardingDone,
      ),
      isTrue,
    );
  });

  testWidgets('ONB-14 change contact returns to form and closes gate', (
    tester,
  ) async {
    await tester.runAsync(
      () => ContactService.savePrimaryEmergencyContact(
        name: 'Ayşe',
        phone: '+905001234567',
      ),
    );
    await pumpLocalized(tester, const OnboardingScreen());
    await skipToContact(tester);
    expect(
      find.text('Ayşe birincil acil kişiniz olarak kaydedildi.'),
      findsOneWidget,
    );

    final change = find.text('Farklı bir kişi gir');
    await tester.ensureVisible(change);
    await tester.tap(change);
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Başla'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('ONB-12 consent dialog cancel leaves contact unsaved', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);
    await openFilledContactForm(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'İptal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Kişi Ekleme Onayı'), findsNothing);
    expect(await ContactService.getEmergencyContact(), isNull);
    expect(find.text('Kişiyi kaydet'), findsOneWidget);
  });

  testWidgets('ONB-10/ONB-13 consent confirm persists primary contact', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);
    await openFilledContactForm(tester);
    final add = find.widgetWithText(ElevatedButton, 'Ekle');
    expect(tester.widget<ElevatedButton>(add).onPressed, isNull);

    await tester.tap(find.text(
      'Bu kişiyi uygulamaya eklediğimi bildirdiğimi ve rızasını '
      'aldığımı beyan ederim.',
    ));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(add).onPressed, isNotNull);
    await tester.tap(add);
    for (var round = 0; round < 20; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
      if (find.text('Zeynep birincil acil kişiniz olarak kaydedildi.')
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    final contact = await ContactService.getEmergencyContact();
    expect(contact?.name, 'Zeynep');
    expect(contact?.phone, '+905551112233');
    expect(
      find.text('Zeynep birincil acil kişiniz olarak kaydedildi.'),
      findsOneWidget,
    );
  });
}
