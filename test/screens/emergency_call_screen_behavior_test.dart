import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/call_service.dart';
import 'package:guvenlik_app/screens/emergency_call_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _Host extends StatelessWidget {
  const _Host({required this.screen});

  final Widget screen;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(
          context,
        ).push<void>(MaterialPageRoute<void>(builder: (_) => screen)),
        child: const Text('OPEN_RESULT'),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpResult(
    WidgetTester tester, {
    String name = 'Acil Kişi',
    String phone = '+905551112233',
  }) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr', 'TR')],
        path: 'assets/translations',
        assetLoader: const _RealTrAssetLoader(),
        startLocale: const Locale('tr', 'TR'),
        fallbackLocale: const Locale('tr', 'TR'),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: _Host(
              screen: EmergencyCallScreen(
                name: name,
                phone: phone,
                callResult: EmergencyCallResult.failed(phone),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('OPEN_RESULT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(EmergencyCallScreen), findsOneWidget);
  }

  testWidgets(
    'SNC-05: fail-safe blocks Back and Kapat closes only the dialog',
    (tester) async {
      await pumpResult(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(EmergencyCallScreen), findsOneWidget);

      await tester.tap(find.text('Kapat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(EmergencyCallScreen), findsOneWidget);
    },
  );

  testWidgets('SNC-06: home control pops every emergency result route', (
    tester,
  ) async {
    await pumpResult(tester);

    final homeControl = find.ancestor(
      of: find.byIcon(Icons.home_rounded),
      matching: find.byType(InkWell),
    );
    expect(homeControl, findsOneWidget);
    await tester.tap(homeControl);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('OPEN_RESULT'), findsOneWidget);
    expect(find.byType(EmergencyCallScreen), findsNothing);
  });

  testWidgets('SNC-08: masked name does not implicitly mask the phone number', (
    tester,
  ) async {
    await pumpResult(tester, name: 'A***', phone: '+905551112233');

    expect(find.text('A***'), findsOneWidget);
    expect(find.text('+905551112233'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(
      find.text('+905551112233'),
      findsNWidgets(2),
      reason:
          'numara hem sonuç ekranında hem fail-safe yüzeyinde açık gösterilir',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
