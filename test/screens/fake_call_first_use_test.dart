// FKC-05's "accept" branch lives in its own file ON PURPOSE.
//
// Only one test per isolate can take the first-use-dialog path: see the note at
// the top of `fake_call_harness.dart`. Two dialog tests in one file do not fail,
// they hang -- `audioplayers` cannot create a second player under the fake clock,
// and `_checkFirstUseWarning` awaits `_stopRingtone()` before it shows the
// dialog. The "cancel" branch is in `fake_call_behavior_test.dart`.

import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('FKC-05 first-use accept persists consent and keeps call open', (
    tester,
  ) async {
    await tester.runAsync(() => h.configure(warned: false, consent: false));
    await pumpFakeCall(tester, FakeCallSettled.warning);

    await tester.tap(find.text('Anladım, Devam Et'));
    await drainAsyncFrames(tester);

    expect(find.byType(FakeCallScreen), findsOneWidget);
    expect(h.consentManager.isGranted(ConsentRecord.typeFakeCall), isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool('pref_fake_call_warned'),
      isTrue,
    );
  });
}
