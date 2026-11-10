import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/screens/settings_legal/contact_backup_screen.dart';
import 'package:guvenlik_app/screens/settings_legal/legal_settings_screen.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/contact_service_test_support.dart';
import 'accessibility_guidelines_test.dart' show pumpLocalized;

/// allowBackup=false is deliberate, so the app must SAY what it means for the
/// user: a new phone starts empty. These tests pin that the statement is
/// reachable from Settings and that the backup controls are usable.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(FakeSecureStorage());
    final consentManager = ConsentManager();
    await consentManager.initialize();
    serviceLocator.registerSingleton<ConsentManager>(consentManager);
  });

  tearDown(() => serviceLocator.reset());

  // ElevatedButton.icon builds a private subclass, so match by `is`, not by
  // exact runtime type as find.widgetWithText would.
  Finder button(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
  );

  testWidgets(
    'legal settings states that contacts do not move to a new phone',
    (tester) async {
      await pumpLocalized(tester, const LegalSettingsScreen());
      await tester.pumpAndSettle();

      final subtitle = find.text(
        'Telefon değişirse kişiler otomatik taşınmaz — yedek alın',
      );
      await tester.ensureVisible(subtitle);
      expect(subtitle, findsOneWidget);

      await tester.tap(find.text('Kişi Yedeği'));
      await tester.pumpAndSettle();
      expect(find.byType(ContactBackupScreen), findsOneWidget);
      expect(find.text('Yeni telefona otomatik aktarım yok'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(LegalSettingsScreen), findsOneWidget);
    },
  );

  testWidgets('both backup actions are labelled buttons of at least 48 dp', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpLocalized(tester, const ContactBackupScreen());
    await tester.pumpAndSettle();

    for (final label in ['Yedek Dosyası Oluştur', 'Yedekten Geri Yükle']) {
      final finder = button(label);
      await tester.ensureVisible(finder);
      expect(finder, findsOneWidget);
      // Global coordinates, never SemanticsNode.rect (repo DoD).
      final rect = tester.getRect(finder);
      expect(rect.height, greaterThanOrEqualTo(48), reason: label);
      expect(rect.width, greaterThanOrEqualTo(48), reason: label);
      expect(
        tester.getSemantics(finder),
        containsSemantics(isButton: true, label: label),
      );
    }
    semantics.dispose();
  });

  testWidgets('export password dialog enforces length and confirmation', (
    tester,
  ) async {
    await pumpLocalized(tester, const ContactBackupScreen());
    await tester.pumpAndSettle();

    final export = button('Yedek Dosyası Oluştur');
    await tester.ensureVisible(export);
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(find.text('Yedek şifresi belirleyin'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    for (final field in tester.widgetList<TextField>(fields)) {
      expect(field.obscureText, isTrue);
      expect(field.enableSuggestions, isFalse);
    }

    await tester.enterText(fields.at(0), 'kisa');
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('Şifre en az 8 karakter olmalı'), findsOneWidget);

    await tester.enterText(fields.at(0), 'uzun-sifre-1');
    await tester.enterText(fields.at(1), 'uzun-sifre-2');
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('Şifreler eşleşmiyor'), findsOneWidget);

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(find.text('Yedek şifresi belirleyin'), findsNothing);
    expect(button('Yedek Dosyası Oluştur'), findsOneWidget);
  });
}
