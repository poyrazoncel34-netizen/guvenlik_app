import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/domain/models/activity_event.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/screens/fake_call_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_call_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final FakeCallHarness h = FakeCallHarness();

  setUpAll(FakeCallHarness.installAudioFakes);
  tearDown(h.tearDownHarness);

  testWidgets('FKC-05 first-use cancel pops without granting consent', (
    tester,
  ) async {
    await tester.runAsync(() => h.configure(warned: false, consent: false));
    await pumpFakeCall(tester, FakeCallSettled.warning);

    expect(find.text('Sahte Çağrı Uyarısı'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(FakeCallScreen))).canPop(),
      isTrue,
    );
    await tester.tap(find.text('İptal'));
    await drainAsyncFrames(tester);

    expect(find.byType(FakeCallScreen), findsNothing);
    expect(find.text('OPEN_FAKE_CALL'), findsOneWidget);
    expect(h.consentManager.isGranted(ConsentRecord.typeFakeCall), isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool('pref_fake_call_warned'),
      isFalse,
    );
    await h.unmount(tester);
  });


  testWidgets('FKC-06 missing consent closes an already-warned fake call', (
    tester,
  ) async {
    await tester.runAsync(() => h.configure(warned: true, consent: false));
    await pumpFakeCall(tester, FakeCallSettled.dismissed);

    expect(find.byType(FakeCallScreen), findsNothing);
    expect(find.text('OPEN_FAKE_CALL'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  for (final action in <({String id, String label, IconData? icon, bool logs})>[
    (
      id: 'FKC-08',
      label: 'Reddet',
      icon: Icons.call_end_rounded,
      logs: true,
    ),
    (id: 'FKC-09', label: 'Kabul Et', icon: Icons.call_rounded, logs: true),
    (
      id: 'FKC-10',
      label: 'üst kapatma',
      icon: Icons.arrow_back_ios_new_rounded,
      logs: false,
    ),
  ]) {
    testWidgets('${action.id} ${action.label} stops and pops the real screen', (
      tester,
    ) async {
      await tester.runAsync(() => h.configure(warned: true, consent: true));
      await pumpFakeCall(tester, FakeCallSettled.ringing);

      await tester.tap(find.byIcon(action.icon!));
      await drainAsyncFrames(tester);

      expect(find.byType(FakeCallScreen), findsNothing);
      expect(find.text('OPEN_FAKE_CALL'), findsOneWidget);
      final rows = await queryEvents(tester, h.db);
      expect(rows, action.logs ? hasLength(1) : isEmpty);
      if (action.logs) {
        expect(rows.single['type'], ActivityType.fakeCallUsed.name);
      }
    });
  }

  testWidgets('FKC-11/FKC-13/FKC-14 customize preset and save defaults', (
    tester,
  ) async {
    await tester.runAsync(() => h.configure(warned: true, consent: true));
    await pumpFakeCall(tester, FakeCallSettled.ringing);

    await tester.tap(find.text('Ayarla'));
    await pumpUntilStill(
      tester,
      'the customize sheet',
      find.text('Sahte Çağrı Ayarları'),
    );
    expect(find.text('Sahte Çağrı Ayarları'), findsOneWidget);

    final fields = find.byType(TextField);
    final String numberBeforePreset =
        tester.widget<TextField>(fields.at(1)).controller?.text ?? '';

    await tester.tap(find.text('Patron'));
    await tester.pump();

    // FKC-13 as built sets the NAME only. The inventory describes the chips as
    // filling "ad/numara", but all four call sites pass an empty phone and
    // `_buildTemplateChip` guards on `phone.isNotEmpty`, so the phone branch is
    // unreachable. Asserted as it behaves, with the number as a negative control
    // -- writing the inventory's wording in here instead would have made this
    // test fail for the right reason and then be "fixed" by loosening it.
    expect(tester.widget<TextField>(fields.at(0)).controller?.text, 'Patron');
    expect(
      tester.widget<TextField>(fields.at(1)).controller?.text,
      numberBeforePreset,
      reason: 'the preset must not touch the number field',
    );

    await tester.enterText(fields.at(0), '');
    await tester.enterText(fields.at(1), '');
    await tester.tap(find.text('Kaydet'));
    await pumpUntil(
      tester,
      'the customize sheet to save and close',
      () => find.text('Sahte Çağrı Ayarları').evaluate().isEmpty,
    );

    expect(find.text('Sahte Çağrı Ayarları'), findsNothing);
    expect(h.storage.values[SecureStorageKeys.fakeCallName], 'Arkadaşım');
    expect(h.storage.values[SecureStorageKeys.fakeCallNumber], 'Numara girilmedi');
    expect(find.text('Arkadaşım'), findsOneWidget);
  });
}
