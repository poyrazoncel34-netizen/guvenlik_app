// Accessibility guideline coverage with a harness that can actually fail.
//
// HISTORY -- an independent reviewer found the previous version of this file
// vacuous. It pumped the UI with only DefaultMaterialLocalizations, so
// easy_localization resolved every key to the KEY STRING itself. Because
// `labeledTapTargetGuideline` only requires a NON-EMPTY accessible name, and a
// key string is always non-empty, that assertion could not fail -- not for a
// missing translation, not for an empty label, not for a meaningless one.
//
// Two things changed:
//   1. EasyLocalization is initialised against the REAL shipped tr-TR.json, so
//      the tree carries real Turkish copy. `assertRealCopyRendered` fails the
//      run if raw keys leak through, which is what made the old harness blind.
//   2. `negative control` below proves the matchers still reject a genuinely
//      inaccessible widget in THIS configuration. Without that, a green run
//      only shows the matchers ran, not that they work.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/onboarding_contact_gate_service.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:guvenlik_app/screens/legal/unified_consent_screen.dart';
import 'package:guvenlik_app/screens/onboarding/onboarding_contact_step.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:guvenlik_app/widgets/panic_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/contact_service_test_support.dart';

/// Serves the REAL shipped catalogue. A stub would reintroduce the defect this
/// file exists to prevent.
class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final raw = File('assets/translations/tr-TR.json').readAsStringSync();
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

class _FixedAccessProvider extends SubscriptionProvider {
  _FixedAccessProvider(this._state);
  final SubscriptionAccessState _state;
  @override
  SubscriptionAccessState get access => _state;
  @override
  Future<SubscriptionAccessState> resolveAccess() async => _state;
}

/// Fails if any rendered string is still a raw localization key.
///
/// This is the guard the old harness lacked: without it, an unloaded catalogue
/// silently satisfies every "has a non-empty label" assertion below.
void assertRealCopyRendered(WidgetTester tester) {
  final leaked = <String>[];
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data;
    if (data == null || data.isEmpty) continue;
    // Localization keys in this project are lower_snake_case ASCII with no
    // spaces. Real Turkish copy is not.
    if (RegExp(r'^[a-z0-9]+(_[a-z0-9]+){2,}$').hasMatch(data)) {
      leaked.add(data);
    }
  }
  expect(
    leaked,
    isEmpty,
    reason:
        'Raw localization keys reached the tree: $leaked. Every accessible-name '
        'assertion in this file would then pass on the key string instead of on '
        'real copy, which is exactly how this harness was previously vacuous.',
  );
}

Future<void> pumpLocalized(WidgetTester tester, Widget child) async {
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
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  // EasyLocalization loads its catalogue asynchronously, so the child only
  // MOUNTS after the first settle -- and only then does the step start its own
  // storage read. One runAsync window covers the catalogue, not the child, so
  // drive a second one. Without this the step is still on its spinner and every
  // assertion below passes vacuously against an empty tree.
  // Poll until the screen settles instead of guessing a delay: the first test
  // in a file pays the sqflite-ffi and catalogue init cost, so a fixed number
  // of rounds is green locally and flaky on a loaded machine. Bounded so a
  // genuinely stuck screen still fails.
  for (var round = 0; round < 20; round++) {
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        find.byType(Text).evaluate().isNotEmpty) {
      break;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

/// Hard precondition: a screen still on its loading spinner has no labels, so
/// every accessibility assertion against it would be vacuously true.
void assertScreenSettled(WidgetTester tester) {
  expect(
    find.byType(CircularProgressIndicator),
    findsNothing,
    reason:
        'The screen is still loading. Accessibility assertions against a '
        'spinner prove nothing -- this is the vacuity IR-03 flagged.',
  );
  expect(
    find.byType(Text),
    findsWidgets,
    reason: 'No text rendered; the tree is empty and matchers cannot fail.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'warning_panic_shown': true,
    });
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(FakeSecureStorage());
    serviceLocator.registerSingleton<LocalDatabaseService>(
      FakeLocalDatabaseService(),
    );
    ContactService.resetCache();
    final consent = ConsentManager();
    await consent.initialize();
    serviceLocator.registerSingleton<ConsentManager>(consent);
    await OnboardingContactGateService.grantContactDataConsent(locale: 'tr');
  });

  tearDown(() async {
    ContactService.resetCache();
    await serviceLocator.reset();
  });

  group('negative control -- the matchers must be able to fail', () {
    testWidgets('an unlabelled icon button is REJECTED', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(width: 48, height: 48),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // If this ever stops throwing, every "labelled target" pass in this file
      // is meaningless and must be re-examined.
      bool rejected = false;
      try {
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } on TestFailure {
        rejected = true;
      }
      expect(
        rejected,
        isTrue,
        reason:
            'labeledTapTargetGuideline accepted a tappable node with no '
            'accessible name -- the matcher has no teeth in this harness.',
      );
      handle.dispose();
    });

    testWidgets('an undersized tap target is REJECTED', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                label: 'kucuk dugme',
                child: GestureDetector(
                  onTap: () {},
                  child: const SizedBox(width: 12, height: 12),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      bool rejected = false;
      try {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } on TestFailure {
        rejected = true;
      }
      expect(
        rejected,
        isTrue,
        reason: 'androidTapTargetGuideline accepted a 12x12 tap target.',
      );
      handle.dispose();
    });
  });

  group('onboarding contact step', () {
    testWidgets('renders real Turkish copy, not localization keys', (
      tester,
    ) async {
      await pumpLocalized(tester, OnboardingContactStep(onGateChanged: (_) {}));
      assertScreenSettled(tester);
      assertRealCopyRendered(tester);
      expect(find.textContaining('Acil kişinizi ekleyin'), findsOneWidget);
    });

    testWidgets('meets tap-target and labelled-target guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpLocalized(tester, OnboardingContactStep(onGateChanged: (_) {}));
      assertScreenSettled(tester);
      assertRealCopyRendered(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('panic button -- the app\'s single most important control', () {
    Widget panic(SubscriptionAccessState state) =>
        ChangeNotifierProvider<SubscriptionProvider>.value(
          value: _FixedAccessProvider(state),
          child: const PanicButton(),
        );

    final pro = const SubscriptionAccessState.uninitialized()
        .markVerified(isPro: true);

    testWidgets('entitled state renders real copy and meets guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpLocalized(tester, panic(pro));
      assertScreenSettled(tester);
      assertRealCopyRendered(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('locked state still exposes a real accessible name', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpLocalized(
        tester,
        panic(
          const SubscriptionAccessState(
            status: SubscriptionAccessStatus.unavailable,
          ),
        ),
      );
      assertScreenSettled(tester);
      assertRealCopyRendered(tester);
      // A locked SOS control that announces nothing is unusable to a
      // screen-reader user at the moment it matters most.
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('consent gate -- the first screen every user sees', () {
    testWidgets('renders real copy and meets tap-target guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpLocalized(tester, const UnifiedConsentScreen());
      assertScreenSettled(tester);
      assertRealCopyRendered(tester);
      // Consent checkboxes are the gate to the whole product; one that is too
      // small to hit reliably blocks setup entirely.
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
