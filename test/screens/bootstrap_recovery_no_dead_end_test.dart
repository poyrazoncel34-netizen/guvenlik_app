import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/screens/bootstrap_recovery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves the REAL shipped Turkish catalogue, like the neighbouring tests.
class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final raw = File('assets/translations/tr-TR.json').readAsStringSync();
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

Map<String, dynamic> _tr() =>
    jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
        as Map<String, dynamic>;

Future<void> _pump(
  WidgetTester tester, {
  required String reasonCode,
  required BootstrapRetry retry,
  required LocalDataReset reset,
  required VoidCallback onRecovered,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const <Locale>[Locale('tr', 'TR')],
      path: 'assets/translations',
      assetLoader: const _RealTrAssetLoader(),
      startLocale: const Locale('tr', 'TR'),
      fallbackLocale: const Locale('tr', 'TR'),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: BootstrapRecoveryScreen(
            reasonCode: reasonCode,
            retryBootstrap: retry,
            hasActiveSafetySession: () async => false,
            resetLocalData: reset,
            onRecovered: onRecovered,
          ),
        ),
      ),
    ),
  );
  // Bounded pumps: let the asset loader resolve, never pumpAndSettle.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

ButtonStyleButton _button(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  const storageReasons = <String>[
    'pinFailed',
    'pinTimeout',
    'contactFailed',
    'contactTimeout',
  ];

  for (final reason in storageReasons) {
    testWidgets('$reason: both exits are present and enabled, no raw keys', (
      tester,
    ) async {
      await _pump(
        tester,
        reasonCode: reason,
        retry: () async => false,
        reset: () async => WipeResult.completed,
        onRecovered: () {},
      );

      expect(find.text('Güvenli başlatma tamamlanamadı'), findsOneWidget);
      expect(_button(tester, 'Yeniden Dene').onPressed, isNotNull);
      expect(_button(tester, 'Yerel Verileri Sıfırla').onPressed, isNotNull);
      expect(
        find.textContaining('bootstrap_recovery_'),
        findsNothing,
        reason: 'an unresolved key renders as raw text in release',
      );
    });
  }

  test('the reset hint names the exact token the dialog accepts', () {
    for (final path in const [
      'assets/translations/tr-TR.json',
      'assets/translations/en-US.json',
    ]) {
      final catalogue =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final token = catalogue['forgot_pin_reset_token'] as String;
      final hint = catalogue['bootstrap_recovery_reset_dialog_hint'] as String;
      expect(hint, contains(token), reason: path);
    }
  });

  testWidgets('a slow keystore (pinTimeout) keeps the original body text', (
    tester,
  ) async {
    await _pump(
      tester,
      reasonCode: 'pinTimeout',
      retry: () async => false,
      reset: () async => WipeResult.completed,
      onRecovered: () {},
    );

    expect(
      find.text(
        'PIN güvenli depodan okunamadığı için uygulama kilitli tutuluyor. '
        'Yeniden deneyebilir veya cihazdaki yerel verileri açık onayla '
        'sıfırlayabilirsiniz.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('persistent PIN failure states the data loss before any reset', (
    tester,
  ) async {
    await _pump(
      tester,
      reasonCode: 'pinFailed',
      retry: () async => false,
      reset: () async => WipeResult.completed,
      onRecovered: () {},
    );

    final body = _tr()['bootstrap_recovery_body_persistent'] as String?;
    expect(body, isNotNull);
    expect(find.text(body!), findsOneWidget);
    expect(body, contains('kişiler'));
    expect(body, contains('kalıcı olarak silinir'));
  });

  testWidgets('contact store failure names the contacts, not the PIN', (
    tester,
  ) async {
    await _pump(
      tester,
      reasonCode: 'contactFailed',
      retry: () async => false,
      reset: () async => WipeResult.completed,
      onRecovered: () {},
    );

    final body = _tr()['bootstrap_recovery_body_contacts'] as String?;
    expect(body, isNotNull);
    expect(find.text(body!), findsOneWidget);
  });

  testWidgets('transient: a successful retry leaves the recovery screen', (
    tester,
  ) async {
    var recovered = false;
    await _pump(
      tester,
      reasonCode: 'pinTimeout',
      retry: () async => true,
      reset: () async => WipeResult.completed,
      onRecovered: () => recovered = true,
    );

    await tester.tap(find.text('Yeniden Dene'));
    await tester.pump();

    expect(recovered, isTrue);
  });

  testWidgets('persistent: retry keeps failing, typed reset still exits', (
    tester,
  ) async {
    var recovered = false;
    var wiped = false;
    await _pump(
      tester,
      reasonCode: 'pinFailed',
      retry: () async => wiped,
      reset: () async {
        wiped = true;
        return WipeResult.completed;
      },
      onRecovered: () => recovered = true,
    );

    await tester.tap(find.text('Yeniden Dene'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(recovered, isFalse);
    expect(
      find.text('Güvenli depolama hâlâ okunamıyor. Yeniden deneyin.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Yerel Verileri Sıfırla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(
        'Bu işlem PIN, kişiler ve ayarlar dahil cihazdaki KoruBeni '
        'verilerini kalıcı olarak siler.',
      ),
      findsOneWidget,
    );
    expect(find.text('SIFIRLA yazarak onaylayın'), findsOneWidget);
    expect(_button(tester, 'Sıfırla').onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'SIFIRLA');
    await tester.pump();
    await tester.tap(find.text('Sıfırla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(wiped, isTrue);
    expect(recovered, isTrue);
  });
}
