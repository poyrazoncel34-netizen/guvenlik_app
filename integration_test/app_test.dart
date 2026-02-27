// ============================================================================
// INTEGRATION TEST: Panik butonu -> PIN doğrulama -> geri sayım akışı
// ============================================================================
//
// Çalıştırma: flutter test integration_test/app_test.dart
// (veya cihaz/emülatör ile: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart)

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/main.dart' as app;
import 'package:guvenlik_app/widgets/panic_button.dart';
import 'package:guvenlik_app/screens/pin_verification_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Panik akışı integration testleri', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({
        AppConstants.prefOnboardingDone: true,
        AppConstants.prefPinSetupDone: true,
      });
    });

    testWidgets(
      'Panik butonuna basılı tutup bırakınca PinVerificationScreen açılır',
      (WidgetTester tester) async {
        app.main();

        // Splash ~1.8s + navigation
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Ana sayfada PanicButton bulunmalı
        expect(find.byType(PanicButton), findsOneWidget);

        // Panik butonuna basılı tut (long press start + end)
        await tester.longPress(find.byType(PanicButton));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // PinVerificationScreen açılmış olmalı
        expect(find.byType(PinVerificationScreen), findsOneWidget);
      },
    );
  });
}
