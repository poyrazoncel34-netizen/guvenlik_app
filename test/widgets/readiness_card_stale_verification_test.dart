// The advance-warning UX required by INDEPENDENT_REVIEW.md IR-04.
//
// Before this, `offlineGracePeriod` was referenced only inside its own file:
// nothing told a subscriber that entitlement verification was going stale. The
// notice must also be CALM -- under the IR-04 policy the emergency action keeps
// working while offline, so alarming copy would be factually wrong.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/widgets/readiness_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

Future<void> pumpCard(WidgetTester tester, {required bool stale}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 1400);
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
            home: Scaffold(
              body: SingleChildScrollView(
                child: ReadinessCard(
                  locationGranted: true,
                  contactsGranted: true,
                  hasEmergencyContact: true,
                  readiness: null,
                  lastRehearsalAt: null,
                  onFixEmergencyContact: () {},
                  onFixCallPermission: () {},
                  onFixBackground: () {},
                  onFixLocation: () {},
                  onFixContacts: () {},
                  onRunRehearsal: () {},
                  subscriptionVerificationStale: stale,
                ),
              ),
            ),
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

Finder textContaining(String needle) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').contains(needle),
  description: 'Text containing "$needle"',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('stale verification renders an advance notice', (tester) async {
    await pumpCard(tester, stale: true);
    expect(textContaining('Abonelik doğrulaması bekliyor'), findsOneWidget);
    expect(textContaining('çevrimdışı'), findsOneWidget);
  });

  testWidgets('the notice states that emergency features keep working', (
    tester,
  ) async {
    await pumpCard(tester, stale: true);
    // The whole point of the IR-04 policy: do not imply SOS is at risk.
    expect(
      textContaining('Acil durum özellikleri çalışmaya devam ediyor'),
      findsOneWidget,
      reason:
          'Copy must reassure, not alarm -- the emergency action is unaffected '
          'while entitlement is merely unverifiable.',
    );
  });

  testWidgets('the notice is not shown when verification is healthy', (
    tester,
  ) async {
    await pumpCard(tester, stale: false);
    expect(textContaining('Abonelik doğrulaması bekliyor'), findsNothing);
  });

  testWidgets('the notice is exposed to screen readers as one unit', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpCard(tester, stale: true);
    expect(
      find.bySemanticsLabel(RegExp('Abonelik doğrulaması bekliyor')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
