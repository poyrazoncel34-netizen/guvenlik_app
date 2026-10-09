import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    EmergencyCallResult? result,
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
                callResult: result ?? EmergencyCallResult.failed(phone),
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

  // Y-02 (owner decision 2026-10-09): Android Telecom ACCEPTING the request is
  // REQUEST_SUBMITTED_UNCONFIRMED -- not a failure. Five seconds after every
  // accepted request the screen said "Yardım çağrısı henüz gitmedi / Arama
  // bağlanmadı ... manuel arayın" and asked for the green call button, while
  // the call was ringing on the same phone (API 35/36 emulators): a push
  // toward a second, unnecessary call.
  group('Y-02: what each call result is allowed to claim', () {
    Map<String, dynamic> catalogue() =>
        jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
            as Map<String, dynamic>;
    String tr(String key) => catalogue()[key] as String;

    testWidgets('an accepted request claims neither failure nor connection, '
        'and offers no second call', (tester) async {
      await pumpResult(
        tester,
        result: EmergencyCallResult.requested('+905551112233'),
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(tr('emergency_flow_requested_title')), findsOneWidget);
      expect(
        find.textContaining('doğrulayamaz'),
        findsWidgets,
        reason: 'the user is told what KoruBeni cannot know',
      );
      // Claims, not words: "bağlanıp bağlanmadığını ... doğrulayamaz" is the
      // required disclaimer and contains "bağlanmadı".
      for (final forbidden in <String>[
        'henüz gitmedi',
        'Arama bağlanmadı',
        'yeşil arama',
        'cevapladı',
      ]) {
        expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
      }
      expect(find.text(tr('emergency_manual_call_now')), findsNothing);
    });

    // Security review MEDIUM-7: Telecom can accept the request and the call
    // still fail (no signal). With the manual call gone, the screen left no
    // way to the dialer. A quiet link opens the phone app with the number
    // filled in -- it places nothing; the user still presses call.
    testWidgets('an accepted request keeps a quiet way to the phone app that '
        'dials nothing by itself', (tester) async {
      final launched = <String>[];
      const launcher = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(launcher, (
        call,
      ) async {
        launched.add('${call.method} ${call.arguments}');
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          launcher,
          null,
        ),
      );
      await pumpResult(
        tester,
        result: EmergencyCallResult.requested('+905551112233'),
      );

      final link = find.text(tr('emergency_open_phone_app'));
      expect(link, findsOneWidget);
      final button = find.ancestor(
        of: link,
        matching: find.byWidgetPredicate((w) => w is TextButton),
      );
      expect(tester.getRect(button).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(button),
        containsSemantics(isButton: true, label: tr('emergency_open_phone_app')),
      );
      expect(launched, isEmpty);

      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pump();
      expect(launched.join(), contains('tel:+905551112233'));
      expect(find.byType(EmergencyCallScreen), findsOneWidget);
    });

    // On a 1080x2400 px / 420 dpi emulator (411x914 dp) the link, placed at
    // the end of the scroll view, overflowed it and was cut through its text
    // at rest. The link and what the request means must be readable without
    // scrolling.
    testWidgets('on a 411x914 dp phone the link and the request banner are '
        'fully visible at rest', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await pumpResult(
        tester,
        result: EmergencyCallResult.requested('+905551112233'),
      );

      bool fullyVisible(Finder f) {
        final rect = tester.getRect(f);
        final screen = Offset.zero & const Size(1080 / 2.625, 2400 / 2.625);
        if (rect.top < screen.top || rect.bottom > screen.bottom) return false;
        final scrollable = find.ancestor(of: f, matching: find.byType(Scrollable));
        if (scrollable.evaluate().isEmpty) return true;
        final viewport = tester.getRect(scrollable.first);
        return viewport.top <= rect.top && rect.bottom <= viewport.bottom;
      }

      // The status card's long hint is checked on the device: the test font
      // is far wider than Roboto, so it wraps into more lines here.
      for (final key in <String>[
        'emergency_open_phone_app',
        'emergency_flow_requested_body',
      ]) {
        expect(fullyVisible(find.text(tr(key))), isTrue, reason: key);
      }
    });

    testWidgets('a dialer fallback asks for the green button without claiming '
        'the call did not go', (tester) async {
      await pumpResult(
        tester,
        result: EmergencyCallResult.dialer('+905551112233'),
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(tr('failsafe_dialer_title')), findsOneWidget);
      expect(find.text(tr('emergency_open_phone_app')), findsNothing);
      expect(find.textContaining('henüz gitmedi'), findsNothing);
      expect(find.textContaining('Arama bağlanmadı'), findsNothing);
    });

    testWidgets('a failed request says so and offers the manual call', (
      tester,
    ) async {
      await pumpResult(tester);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(tr('failsafe_title')), findsOneWidget);
      expect(find.text(tr('emergency_manual_call_now')), findsOneWidget);
      expect(
        find.text(tr('emergency_open_phone_app')),
        findsNothing,
        reason: 'a real failure gets the manual call, not the quiet link',
      );
    });
  });
}
