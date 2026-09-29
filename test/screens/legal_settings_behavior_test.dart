import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/screens/legal/consent_management_screen.dart';
import 'package:guvenlik_app/screens/legal/kvkk_disclosure_screen.dart';
import 'package:guvenlik_app/screens/legal/terms_of_service_screen.dart';
import 'package:guvenlik_app/screens/settings_legal/data_deletion_screen.dart';
import 'package:guvenlik_app/screens/settings_legal/data_export_screen.dart';
import 'package:guvenlik_app/screens/settings_legal/legal_settings_screen.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

Future<void> _pumpLegalSettings(WidgetTester tester) async {
  await pumpLocalized(tester, const LegalSettingsScreen());
  await tester.pumpAndSettle();
}

Future<void> _tapVisibleText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    final consentManager = ConsentManager();
    await consentManager.initialize();
    serviceLocator.registerSingleton<ConsentManager>(consentManager);
  });

  tearDown(() => serviceLocator.reset());

  testWidgets('YSL-01: app bar back pops the real legal settings route', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    await pumpLocalized(
      tester,
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LegalSettingsScreen(),
              ),
            ),
            child: const Text('Yasal ekranı aç'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Yasal ekranı aç'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalSettingsScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(LegalSettingsScreen), findsNothing);
    expect(find.text('Yasal ekranı aç'), findsOneWidget);
  });

  testWidgets(
    'YSL-02/YSL-09: terms tile opens read-only production screen and back returns',
    (tester) async {
      await _pumpLegalSettings(tester);

      await _tapVisibleText(tester, 'Kullanım Sözleşmesi');
      expect(find.byType(TermsOfServiceScreen), findsOneWidget);
      expect(
        tester
            .widget<TermsOfServiceScreen>(find.byType(TermsOfServiceScreen))
            .isReadOnly,
        isTrue,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(LegalSettingsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'YSL-03/YSL-09: KVKK tile opens read-only production screen and back returns',
    (tester) async {
      await _pumpLegalSettings(tester);

      await _tapVisibleText(tester, 'KVKK Aydınlatma Metni');
      expect(find.byType(KvkkDisclosureScreen), findsOneWidget);
      expect(
        tester
            .widget<KvkkDisclosureScreen>(find.byType(KvkkDisclosureScreen))
            .isReadOnly,
        isTrue,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(LegalSettingsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'YSL-05/YSL-08: consent tile opens production screen and back returns',
    (tester) async {
      await _pumpLegalSettings(tester);

      await _tapVisibleText(tester, 'Rıza Yönetimi');
      expect(find.byType(ConsentManagementScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(LegalSettingsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'YSL-11/EXP-01: export tile opens production screen and back returns',
    (tester) async {
      await _pumpLegalSettings(tester);

      await _tapVisibleText(tester, 'Verilerimi İndir');
      expect(find.byType(DataExportScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(LegalSettingsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'YSL-12/DEL-01: delete tile opens production screen and back returns',
    (tester) async {
      await _pumpLegalSettings(tester);

      await _tapVisibleText(tester, 'Verilerimi Sil');
      expect(find.byType(DataDeletionScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(LegalSettingsScreen), findsOneWidget);
    },
  );
}
