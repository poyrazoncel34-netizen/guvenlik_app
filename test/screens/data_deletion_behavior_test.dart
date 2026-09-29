import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/widgets/subscription_deletion_notice.dart';
import 'package:guvenlik_app/screens/settings_legal/data_deletion_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

Future<void> _pumpDeletion(WidgetTester tester) async {
  await pumpLocalized(tester, const DataDeletionScreen());
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Tüm Verilerimi Sil'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('DEL-02/DEL-03: first deletion confirmation can be cancelled', (
    tester,
  ) async {
    await _pumpDeletion(tester);

    await tester.tap(find.text('Tüm Verilerimi Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Emin misiniz?'), findsOneWidget);
    expect(find.byType(SubscriptionDeletionNotice), findsNWidgets(2));
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();

    expect(find.text('Emin misiniz?'), findsNothing);
    expect(find.byType(DataDeletionScreen), findsOneWidget);
  });

  testWidgets(
    'DEL-02/DEL-03: continuing first confirmation opens the production reset confirmation',
    (tester) async {
      await _pumpDeletion(tester);

      await tester.tap(find.text('Tüm Verilerimi Sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();

      expect(find.text('Emin misiniz?'), findsNothing);
      expect(find.text('Cihaz Verilerini Temizle'), findsNWidgets(2));
      expect(
        find.text(
          'Bu cihazdaki yerel veriler, PIN, acil kişi kayıtları, uygulama '
          'ayarları ve yerel dosyalar silinecek. Devam etmek istediğinizden '
          'emin misiniz?',
        ),
        findsOneWidget,
      );
    },
  );
}
