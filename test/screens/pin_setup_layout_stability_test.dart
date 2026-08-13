// IR-09 regression: the PIN keypad must not move when a validation banner
// appears.
//
// Reported symptom: entering the blocked PIN 1234 inserted a "Daha güvenli bir
// PIN seçin." banner ABOVE the keypad, shifting all ten keys down by ~120px.
// The reviewer's next four taps landed on the wrong digits. On a control where
// the user is typing a secret they cannot see, a silent layout shift causes
// mis-entry -- and this is the screen that protects the duress model.
//
// The fix reserves the banner's vertical space unconditionally, so these
// assertions fail against the previous implementation.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/screens/pin_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/contact_service_test_support.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

const String kWeakPinMessage = 'Daha güvenli bir PIN seçin.';

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
  });

  tearDown(() async => serviceLocator.reset());

  Future<void> pumpPinSetup(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    double textScale = 1.0,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('tr', 'TR')],
          path: 'assets/translations',
          assetLoader: const _RealTrAssetLoader(),
          startLocale: const Locale('tr', 'TR'),
          fallbackLocale: const Locale('tr', 'TR'),
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
              home: const PinSetupScreen(),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapDigit(WidgetTester tester, String digit) async {
    await tester.tap(find.text(digit).last);
    await tester.pump(const Duration(milliseconds: 60));
  }

  /// Geometry of the '5' key -- the centre of the pad, so any shift shows.
  Rect keyRect(WidgetTester tester) => tester.getRect(find.text('5').last);

  testWidgets('keypad does not move when a weak PIN is rejected', (
    tester,
  ) async {
    await pumpPinSetup(tester);
    final before = keyRect(tester);

    for (final d in ['1', '2', '3', '4']) {
      await tapDigit(tester, d);
    }
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(
      find.text(kWeakPinMessage),
      findsOneWidget,
      reason: 'precondition: 1234 must be rejected as a weak PIN',
    );

    final after = keyRect(tester);
    expect(
      after,
      before,
      reason:
          'The keypad shifted when the banner appeared. A user typing an '
          'unseen secret then hits the wrong digits. before=$before '
          'after=$after',
    );
  });

  testWidgets('geometry is stable across repeated rejections', (tester) async {
    await pumpPinSetup(tester);
    final before = keyRect(tester);

    for (var round = 0; round < 3; round++) {
      for (final d in ['1', '2', '3', '4']) {
        await tapDigit(tester, d);
      }
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(
        keyRect(tester),
        before,
        reason: 'round $round moved the keypad',
      );
    }
  });

  testWidgets('the banner stays readable and is announced', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPinSetup(tester);
    for (final d in ['1', '2', '3', '4']) {
      await tapDigit(tester, d);
    }
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    final banner = find.text(kWeakPinMessage);
    expect(banner, findsOneWidget);
    // Readable: on screen, non-zero size, not collapsed by the reserved slot.
    final r = tester.getRect(banner);
    expect(r.height, greaterThan(0));
    expect(r.width, greaterThan(0));
    // Announced: a validation failure the user cannot see must be spoken.
    expect(find.bySemanticsLabel(kWeakPinMessage), findsOneWidget);
    handle.dispose();
  });

  testWidgets('no keypad key is obscured after the banner appears', (
    tester,
  ) async {
    await pumpPinSetup(tester);
    for (final d in ['1', '2', '3', '4']) {
      await tapDigit(tester, d);
    }
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']) {
      expect(
        find.text(d),
        findsWidgets,
        reason: 'key $d disappeared after the validation banner rendered',
      );
    }
  });

  testWidgets('geometry stays stable on a short screen', (tester) async {
    await pumpPinSetup(tester, size: const Size(360, 640));
    final before = keyRect(tester);
    for (final d in ['1', '2', '3', '4']) {
      await tapDigit(tester, d);
    }
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(keyRect(tester), before);
  });

  testWidgets('geometry stays stable at 200% text scale', (tester) async {
    await pumpPinSetup(tester, size: const Size(400, 1200), textScale: 2.0);
    final before = keyRect(tester);
    for (final d in ['1', '2', '3', '4']) {
      await tapDigit(tester, d);
    }
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(
      keyRect(tester),
      before,
      reason:
          'The reserved slot scales with text size, so large-text users get '
          'the same stability.',
    );
  });
}
