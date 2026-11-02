import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/native_contact_picker_service.dart';
import 'package:guvenlik_app/core/services/onboarding_contact_gate_service.dart';
import 'package:guvenlik_app/screens/onboarding/onboarding_contact_step.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/contact_service_test_support.dart';

/// Onboarding is the only gate that can complete setup, and it must reach the
/// same verdict as the contacts page for the same picked contact. Before the
/// fix a NBSP-grouped number landed in the field with an invisible character
/// the user could not find, and a contact without a number did nothing.
///
/// No EasyLocalization host is mounted, so `.tr()` returns the key itself and
/// each assertion names the exact message key an outcome shows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
    messenger.setMockMethodCallHandler(
      NativeContactPickerService.channel,
      null,
    );
    ContactService.resetCache();
    await serviceLocator.reset();
  });

  Future<void> pickWith(
    WidgetTester tester,
    Map<String, String> nativeReply,
  ) async {
    messenger.setMockMethodCallHandler(
      NativeContactPickerService.channel,
      (_) async => nativeReply,
    );
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OnboardingContactStep(onGateChanged: (_) {})),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    for (var round = 0; round < 20; round++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(TextField).evaluate().length == 2) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    expect(
      find.byType(TextField),
      findsNWidgets(2),
      reason: 'harness precondition: the consented contact form must render',
    );

    final pick = find.byWidgetPredicate(
      (widget) => widget is OutlinedButton,
      description: 'pick action',
    );
    expect(pick, findsOneWidget);
    await tester.ensureVisible(pick);
    await tester.tap(pick);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  String fieldText(WidgetTester tester, int index) =>
      tester
          .widget<TextField>(find.byType(TextField).at(index))
          .controller
          ?.text ??
      '';

  testWidgets('a NBSP-grouped pick fills the canonical number with no error', (
    tester,
  ) async {
    await pickWith(tester, {
      'number': '0532\u00A0123\u00A045\u00A067',
      'name': 'Anne',
    });

    expect(fieldText(tester, 0), 'Anne');
    expect(fieldText(tester, 1), '05321234567');
    expect(find.text('onboarding_contact_invalid_phone'), findsNothing);
    expect(find.text('contacts_picked_invalid_phone'), findsNothing);
  });

  testWidgets('a contact without a number shows the no-number notice', (
    tester,
  ) async {
    await pickWith(tester, {'number': '', 'name': 'Anne'});

    expect(find.text('contacts_no_phone'), findsOneWidget);
    expect(fieldText(tester, 1), isEmpty);
  });

  testWidgets('an uncallable pick is offered for correction with its own '
      'message', (tester) async {
    await pickWith(tester, {
      'number': '\u202A*31#0532 123 45 67\u202C',
      'name': 'Anne',
    });

    expect(fieldText(tester, 1), '*31#0532 123 45 67');
    expect(find.text('contacts_picked_invalid_phone'), findsOneWidget);
    expect(find.text('contacts_no_phone'), findsNothing);
  });
}
