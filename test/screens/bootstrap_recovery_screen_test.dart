import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/screens/bootstrap_recovery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The screen's copy lives in the shipped Turkish catalogue; serve it as is so
/// every assertion below still checks the exact user-facing text.
class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final raw = File('assets/translations/tr-TR.json').readAsStringSync();
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  Widget app(Widget child) => EasyLocalization(
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
        home: child,
      ),
    ),
  );

  Future<void> pumpApp(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    // Let the catalogue load; bounded pumps, never pumpAndSettle here.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('retry can recover without exposing the application', (
    tester,
  ) async {
    var recovered = false;
    var resetCalls = 0;

    await pumpApp(
      tester,
      app(
        BootstrapRecoveryScreen(
          reasonCode: 'pinFailed',
          retryBootstrap: () async => true,
          hasActiveSafetySession: () async => false,
          resetLocalData: () async {
            resetCalls++;
            return WipeResult.completed;
          },
          onRecovered: () => recovered = true,
        ),
      ),
    );

    expect(find.text('Güvenli başlatma tamamlanamadı'), findsOneWidget);
    expect(find.text('Yeniden Dene'), findsOneWidget);
    expect(find.text('Yerel Verileri Sıfırla'), findsOneWidget);

    await tester.tap(find.text('Yeniden Dene'));
    await tester.pump();

    expect(recovered, isTrue);
    expect(resetCalls, 0);
  });

  testWidgets('active-session uncertainty blocks unauthenticated reset', (
    tester,
  ) async {
    var resetCalls = 0;

    await pumpApp(
      tester,
      app(
        BootstrapRecoveryScreen(
          reasonCode: 'pinFailed',
          retryBootstrap: () async => false,
          hasActiveSafetySession: () async => true,
          resetLocalData: () async {
            resetCalls++;
            return WipeResult.completed;
          },
          onRecovered: () {},
        ),
      ),
    );

    await tester.tap(find.text('Yerel Verileri Sıfırla'));
    await tester.pump();

    expect(resetCalls, 0);
    expect(
      find.text('Aktif bir güvenlik oturumu varken sıfırlama yapılamaz.'),
      findsOneWidget,
    );
  });

  testWidgets('reset requires typed confirmation and retries bootstrap', (
    tester,
  ) async {
    var resetCalls = 0;
    var retryCalls = 0;
    var recovered = false;

    await pumpApp(
      tester,
      app(
        BootstrapRecoveryScreen(
          reasonCode: 'pinFailed',
          retryBootstrap: () async {
            retryCalls++;
            return true;
          },
          hasActiveSafetySession: () async => false,
          resetLocalData: () async {
            resetCalls++;
            return WipeResult.completed;
          },
          onRecovered: () => recovered = true,
        ),
      ),
    );

    await tester.tap(find.text('Yerel Verileri Sıfırla'));
    await tester.pumpAndSettle();
    expect(find.text('SIFIRLA yazarak onaylayın'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Sıfırla'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), 'SIFIRLA');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sıfırla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(resetCalls, 1);
    expect(retryCalls, 1);
    expect(recovered, isTrue);
  });

  testWidgets('failed reset remains fail-closed and visible', (tester) async {
    var recovered = false;

    await pumpApp(
      tester,
      app(
        BootstrapRecoveryScreen(
          reasonCode: 'pinFailed',
          retryBootstrap: () async => true,
          hasActiveSafetySession: () async => false,
          resetLocalData: () async => WipeResult.unknown,
          onRecovered: () => recovered = true,
        ),
      ),
    );

    await tester.tap(find.text('Yerel Verileri Sıfırla'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'SIFIRLA');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sıfırla'));
    await tester.pumpAndSettle();

    expect(recovered, isFalse);
    expect(
      find.text('Veriler güvenli biçimde silinemedi. Yeniden deneyin.'),
      findsOneWidget,
    );
    expect(find.text('Güvenli başlatma tamamlanamadı'), findsOneWidget);
  });
}
