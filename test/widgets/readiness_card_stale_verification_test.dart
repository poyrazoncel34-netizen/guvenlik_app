// R2-01 regression: the home readiness notice must never claim protection the
// authorization path would refuse.
//
// The card is driven here from a real `SubscriptionAccessState` through
// `noticeFor()` -- the same call `home_page.dart` makes -- rather than from a
// hand-set boolean. A test that passed the flag directly could not have caught
// the original defect, because the defect was in the WIRING between the state
// and the flag.
//
// Also covers the advance warning (IR-04 recommendation #2 / R2-05): the notice
// escalates with the REMAINING non-safety grace, using the
// `isOfflineGraceExpiring` API that previously had no production caller.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';
import 'package:guvenlik_app/core/widgets/readiness_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

final DateTime kNow = DateTime(2026, 8, 13, 12);

SubscriptionAccessState _state(
  SubscriptionAccessStatus status, {
  bool? verified,
  DateTime? verifiedAt,
}) => SubscriptionAccessState(
  status: status,
  lastVerifiedPro: verified,
  lastVerifiedProAt: verifiedAt,
);

/// Pumps the card exactly the way `home_page.dart` builds it: the notice and the
/// remaining-hours argument both derived from ONE access state.
Future<void> pumpCardFor(
  WidgetTester tester,
  SubscriptionAccessState access,
) async {
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
                  subscriptionNotice: access.noticeFor(now: kNow),
                  graceHoursRemaining: access.remainingOfflineGraceHours(
                    now: kNow,
                  ),
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

/// Every rendered Text on screen, joined. Used to assert the ABSENCE of a
/// claim without depending on which widget would have carried it.
String renderedText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join(' | ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  // Harness precondition: the copy under test must actually exist in the real
  // catalogue. Without this, every "findsNothing" below would pass against a
  // typo'd key instead of against correct behaviour.
  test('the notice copy exists in the shipped tr-TR catalogue', () {
    final catalogue =
        jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final key in const [
      'subscription_verification_stale_title',
      'subscription_verification_stale_body',
      'subscription_verification_grace_expiring_title',
      'subscription_verification_grace_expiring_body',
      'subscription_verification_lapsed_title',
      'subscription_verification_lapsed_body',
    ]) {
      expect(catalogue.containsKey(key), isTrue, reason: 'missing key: $key');
    }
    // The continuity sentence is the safety claim under review. Pin it so the
    // absence assertions below cannot pass because the wording drifted.
    expect(
      catalogue['subscription_verification_stale_body'] as String,
      contains('Acil durum özellikleri çalışmaya devam ediyor'),
    );
    // And the "device is offline" assertion must be gone: the app cannot know
    // that, and it was false for the user who saw it (R2-01).
    expect(
      catalogue['subscription_verification_stale_body'] as String,
      isNot(contains('Cihaz çevrimdışı olduğu için')),
    );
  });

  group('R2-01: no protection claim without authorization', () {
    testWidgets('a brand-new never-subscribed user sees NO notice', (
      tester,
    ) async {
      const access = SubscriptionAccessState.uninitialized();
      // Precondition: this is exactly the state the defect rendered from.
      expect(access.isTemporarilyUnverifiable, isTrue);
      expect(access.canUsePaidSafetyFeature, isFalse);

      await pumpCardFor(tester, access);

      expect(textContaining('Abonelik doğrulaması bekliyor'), findsNothing);
      expect(
        renderedText(tester),
        isNot(contains('Acil durum özellikleri çalışmaya devam ediyor')),
        reason:
            'The app told a user with no entitlement that emergency features '
            'keep working. They do not: panic is Pro-gated and '
            'canUsePaidSafetyFeature is false here.',
      );
      expect(renderedText(tester), isNot(contains('çevrimdışı')));
    });

    testWidgets('a never-subscribed user with the store unreachable sees NO '
        'notice', (tester) async {
      final access = _state(SubscriptionAccessStatus.unavailable);
      expect(access.canUsePaidSafetyFeature, isFalse);
      await pumpCardFor(tester, access);
      expect(
        renderedText(tester),
        isNot(contains('Acil durum özellikleri')),
        reason: 'Being offline does not create an entitlement.',
      );
    });

    testWidgets('a confirmed-free user sees NO notice', (tester) async {
      final access = _state(
        SubscriptionAccessStatus.verifiedFree,
        verified: false,
      );
      await pumpCardFor(tester, access);
      expect(textContaining('Abonelik doğrulaması bekliyor'), findsNothing);
      expect(renderedText(tester), isNot(contains('Acil durum özellikleri')));
    });

    testWidgets('a confirmed-active Pro user sees NO notice', (tester) async {
      final access = _state(
        SubscriptionAccessStatus.verifiedPro,
        verified: true,
        verifiedAt: kNow,
      );
      expect(access.canUsePaidSafetyFeature, isTrue);
      await pumpCardFor(tester, access);
      expect(
        textContaining('Abonelik doğrulaması bekliyor'),
        findsNothing,
        reason: 'Nothing is stale: the store answered.',
      );
    });

    testWidgets('while resolution is in flight the card stays silent', (
      tester,
    ) async {
      await pumpCardFor(tester, _state(SubscriptionAccessStatus.loading));
      expect(renderedText(tester), isNot(contains('Acil durum özellikleri')));
    });
  });

  group('R2-05: the notice is driven by remaining grace', () {
    testWidgets('a prior-confirmed subscriber whose store call failed DOES see '
        'the calm notice', (tester) async {
      final access = _state(
        SubscriptionAccessStatus.unavailable,
        verified: true,
        verifiedAt: kNow.subtract(const Duration(hours: 2)),
      );
      // Precondition: for THIS user the claim is true.
      expect(access.canUsePaidSafetyFeature, isTrue);

      await pumpCardFor(tester, access);
      expect(textContaining('Abonelik doğrulaması bekliyor'), findsOneWidget);
      expect(
        textContaining('Acil durum özellikleri çalışmaya devam ediyor'),
        findsOneWidget,
      );
    });

    testWidgets('inside the 48h window the ADVANCE warning names the hours '
        'left', (tester) async {
      final access = _state(
        SubscriptionAccessStatus.unavailable,
        verified: true,
        verifiedAt: kNow.subtract(const Duration(days: 6)),
      );
      expect(access.isOfflineGraceExpiring(now: kNow), isTrue);

      await pumpCardFor(tester, access);
      expect(textContaining('Doğrulama yakında gerekiyor'), findsOneWidget);
      expect(
        textContaining('24 saat'),
        findsOneWidget,
        reason:
            'The warning must report the REMAINING window. A constant string '
            'here would mean isOfflineGraceExpiring is still dead code.',
      );
    });

    testWidgets('after the window lapses the notice says paid extras paused, '
        'not that SOS stopped', (tester) async {
      final access = _state(
        SubscriptionAccessStatus.unavailable,
        verified: true,
        verifiedAt: kNow.subtract(const Duration(days: 90)),
      );
      // Emergency access is UNBOUNDED under IR-04; only the extras lapse.
      expect(access.canUsePaidSafetyFeature, isTrue);
      expect(access.canUseNonEmergencyPaidFeature, isFalse);

      await pumpCardFor(tester, access);
      expect(
        textContaining('Diğer Pro özellikleri duraklatıldı'),
        findsOneWidget,
      );
      expect(
        textContaining('Acil durum özellikleri çalışmaya devam ediyor'),
        findsOneWidget,
      );
    });

    testWidgets('the notice is exposed to screen readers as one unit', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final access = _state(
        SubscriptionAccessStatus.unavailable,
        verified: true,
        verifiedAt: kNow.subtract(const Duration(hours: 2)),
      );
      await pumpCardFor(tester, access);
      expect(
        find.bySemanticsLabel(RegExp('Abonelik doğrulaması bekliyor')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('R2-01: the wiring itself', () {
    // The card now takes an enum that only `noticeFor()` produces, so the old
    // boolean cannot be passed. This guards the remaining hole: a call site
    // reconstructing the defect by mapping the boolean onto the enum.
    test('home_page derives the notice from noticeFor(), not from the '
        'unverifiable boolean', () {
      final source = File('lib/screens/home_page.dart').readAsStringSync();
      expect(
        source,
        contains('subscriptionNotice: subscriptionAccess.noticeFor()'),
        reason: 'The notice must come from the single policy function.',
      );
      expect(
        source,
        isNot(contains('isTemporarilyUnverifiable')),
        reason:
            'Binding home UI to this boolean IS the R2-01 defect. If a future '
            'change needs it, it needs a different requirement first.',
      );
    });
  });
}
