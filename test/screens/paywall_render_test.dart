// Renders the real PaywallScreen with the real shipped Turkish catalogue and
// asserts that every Google Play mandated subscription disclosure is actually
// ON SCREEN.
//
// Why this exists alongside paywall_compliance_test.dart: that file is a
// source-grep contract. It proves the disclosure *strings exist in the file*,
// which cannot distinguish "rendered to the user" from "declared in a widget
// that is never built". Play policy is about what the user sees before paying,
// so the assertion has to be a render assertion.
//
// The RevenueCat SDK is never initialised here. Package/StoreProduct have
// public const constructors, so the plan cards are driven by real model
// objects, and SubscriptionProvider is subclassed to keep initialize() away
// from the platform channel.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:guvenlik_app/screens/subscription/paywall_screen.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves the REAL assets/translations/tr-TR.json from disk. Using the shipped
/// catalogue rather than a stub is the point: a disclosure that regressed in
/// the real bundle must fail this test.
class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final raw = File('assets/translations/tr-TR.json').readAsStringSync();
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

/// Supplies plan data without touching the RevenueCat SDK.
class _StubPaywallProvider extends SubscriptionProvider {
  _StubPaywallProvider({required this.plansAvailable});

  final bool plansAvailable;

  static const _context = PresentedOfferingContext('default', null, null);

  static Package _package(String id, PackageType type, String price) => Package(
    id,
    type,
    StoreProduct(id, 'KoruBeni Pro', 'KoruBeni Pro', 0.0, price, 'TRY'),
    _context,
  );

  @override
  bool get isLoading => false;

  @override
  Offerings? get offerings => null;

  @override
  bool get hasRequiredPackages => plansAvailable;

  @override
  Package? get monthlyPackage => plansAvailable
      ? _package('\$rc_monthly', PackageType.monthly, '₺49,99')
      : null;

  @override
  Package? get annualPackage =>
      plansAvailable ? _package('\$rc_annual', PackageType.annual, '₺399,99') : null;

  // The screen calls this from a post-frame callback; the real one reaches the
  // platform channel.
  @override
  Future<void> initialize() async {}
}

/// Parks `restorePurchases()` so the busy state can be observed. Real async
/// work is what a loading button exists for; a stub that returns immediately
/// would never render the busy frame.
class _ParkedRestoreProvider extends _StubPaywallProvider {
  _ParkedRestoreProvider() : super(plansAvailable: true);

  final Completer<void> gate = Completer<void>();
  int restoreCalls = 0;

  @override
  Future<String?> restorePurchases() async {
    restoreCalls++;
    await gate.future;
    return null;
  }
}

Future<void> _pumpPaywall(
  WidgetTester tester, {
  required bool plansAvailable,
  SubscriptionProvider? provider,
}) async {
  // The paywall is a lazy ListView. At the default 800px test viewport the
  // renewal disclosure, legal links and restore action are below the fold and
  // are never built, so a short viewport silently proves nothing. Render a tall
  // surface so the whole purchase surface is in the tree, and cover the
  // scroll-reachability case separately below.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1080, 3600);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('tr', 'TR')],
      path: 'assets/translations',
      assetLoader: const _RealTrAssetLoader(),
      startLocale: const Locale('tr', 'TR'),
      fallbackLocale: const Locale('tr', 'TR'),
      child: Builder(
        builder: (context) =>
            ChangeNotifierProvider<SubscriptionProvider>.value(
              value:
                  provider ??
                  _StubPaywallProvider(plansAvailable: plansAvailable),
              child: MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: const PaywallScreen(),
              ),
            ),
      ),
    ),
  );
  // Explicit pumps, never pumpAndSettle: this repo's widget tests document
  // that a repeating animation anywhere in the tree makes settle() hang
  // forever (see panic_button_behavior_test.dart). EasyLocalization resolves
  // its catalogue asynchronously, so a few bounded frames are enough.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Map<String, dynamic> _catalogue() =>
    jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
        as Map<String, dynamic>;

/// Finds a Text whose rendered data contains [needle], regardless of how the
/// string is split across the widget tree.
Finder _textContaining(String needle) => find.byWidgetPredicate(
  (widget) => widget is Text && (widget.data ?? '').contains(needle),
  description: 'Text containing "$needle"',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  group('PaywallScreen renders the Play-mandated subscription disclosures', () {
    testWidgets('auto-renewal, billing account and cancellation route are visible', (
      tester,
    ) async {
      await _pumpPaywall(tester, plansAvailable: true);

      // Play requires the user to be told, before purchase, that the
      // subscription auto-renews.
      expect(
        _textContaining('otomatik olarak yenilenir'),
        findsOneWidget,
        reason: 'Auto-renewal disclosure must be rendered on the paywall.',
      );

      // ...that they will be charged through their Play account...
      expect(
        _textContaining('Google Play hesabınızdan'),
        findsOneWidget,
        reason: 'Billing-account disclosure must be rendered.',
      );

      // ...and where to cancel.
      expect(
        _textContaining('Google Play > Abonelikler'),
        findsOneWidget,
        reason:
            'The cancellation route must be rendered, not merely documented.',
      );
    });

    testWidgets('both billing periods and their prices are visible', (
      tester,
    ) async {
      await _pumpPaywall(tester, plansAvailable: true);

      expect(find.text('Yıllık abonelik'), findsOneWidget);
      expect(find.text('Aylık abonelik'), findsOneWidget);
      expect(find.text('₺399,99'), findsOneWidget);
      expect(find.text('₺49,99'), findsOneWidget);
    });

    testWidgets('restore purchases is reachable from the paywall', (
      tester,
    ) async {
      await _pumpPaywall(tester, plansAvailable: true);

      // The entitlement-failure path tells users to use this action, so it has
      // to exist on the screen they are sent to.
      expect(find.text('Satın Alımları Geri Yükle'), findsOneWidget);
    });

    testWidgets('privacy policy and terms links are visible', (tester) async {
      await _pumpPaywall(tester, plansAvailable: true);

      expect(find.text('Gizlilik Politikası'), findsOneWidget);
      expect(find.text('Kullanım Şartları'), findsOneWidget);
    });

    testWidgets(
      'on a real phone viewport the renewal disclosure is reachable by '
      'scrolling the purchase surface',
      (tester) async {
        // Regression guard for how this test itself was first written wrong:
        // the paywall is a lazy ListView, so at a short viewport the
        // disclosure is not merely off-screen, it is never built. That means a
        // naive render assertion passes vacuously. This case pins the property
        // that actually matters to Play policy -- the user can reach the
        // auto-renewal terms from the paywall without leaving it.
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1080, 1920);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('tr', 'TR')],
            path: 'assets/translations',
            assetLoader: const _RealTrAssetLoader(),
            startLocale: const Locale('tr', 'TR'),
            fallbackLocale: const Locale('tr', 'TR'),
            child: Builder(
              builder: (context) =>
                  ChangeNotifierProvider<SubscriptionProvider>.value(
                    value: _StubPaywallProvider(plansAvailable: true),
                    child: MaterialApp(
                      localizationsDelegates: context.localizationDelegates,
                      supportedLocales: context.supportedLocales,
                      locale: context.locale,
                      home: const PaywallScreen(),
                    ),
                  ),
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.drag(find.byType(ListView), const Offset(0, -1400));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(
          _textContaining('otomatik olarak yenilenir'),
          findsOneWidget,
          reason:
              'The auto-renewal disclosure must be reachable by scrolling the '
              'paywall itself.',
        );
        expect(find.text('Satın Alımları Geri Yükle'), findsOneWidget);
      },
    );

    testWidgets(
      'disclosures still render when plans fail to load, so a degraded '
      'paywall can never become a silent purchase surface',
      (tester) async {
        await _pumpPaywall(tester, plansAvailable: false);

        expect(_textContaining('otomatik olarak yenilenir'), findsOneWidget);
        expect(find.text('Satın Alımları Geri Yükle'), findsOneWidget);
        // No price may be shown when no package resolved.
        expect(find.text('₺399,99'), findsNothing);
        expect(find.text('₺49,99'), findsNothing);
      },
    );
  });

  // MP-08-023 "Loading button." Previously this row carried evidence about PIN
  // banner layout stability -- a different requirement entirely
  // (INDEPENDENT_REVIEW_ROUND_2.md R2-09). This is the real thing: an async
  // action must show progress AND refuse re-entry while it runs.
  group('MP-08-023: the restore action is a real loading button', () {
    testWidgets('shows progress and disables itself while the async action '
        'runs, then recovers', (tester) async {
      final provider = _ParkedRestoreProvider();
      await _pumpPaywall(tester, plansAvailable: true, provider: provider);

      // The paywall carries several TextButtons; identify the restore action
      // by its own localized label rather than by type, and use an ancestor
      // finder because `TextButton.icon` builds a private subclass.
      final restoreLabel = _catalogue()['subscription_restore_title'] as String;
      final restoreFinder = find.ancestor(
        of: find.text(restoreLabel),
        matching: find.byWidgetPredicate((w) => w is TextButton),
      );
      expect(
        restoreFinder,
        findsOneWidget,
        reason: 'harness precondition: the restore action must be built',
      );
      // Precondition: idle, enabled, no spinner.
      expect(tester.widget<TextButton>(restoreFinder).onPressed, isNotNull);
      expect(
        find.descendant(
          of: restoreFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );

      await tester.tap(restoreFinder);
      await tester.pump();

      expect(provider.restoreCalls, 1);
      expect(
        find.descendant(
          of: restoreFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'a loading button must show progress while its action runs',
      );
      expect(
        tester.widget<TextButton>(restoreFinder).onPressed,
        isNull,
        reason: 'a loading button must be disabled while its action runs',
      );

      // Re-entry while busy must not start a second restore.
      await tester.tap(restoreFinder, warnIfMissed: false);
      await tester.pump();
      expect(provider.restoreCalls, 1);

      provider.gate.complete();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        tester.widget<TextButton>(restoreFinder).onPressed,
        isNotNull,
        reason: 'the button must become usable again once the action settles',
      );
      expect(
        find.descendant(
          of: restoreFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    });

    testWidgets('plan cards refuse purchase while a restore is in flight', (
      tester,
    ) async {
      final provider = _ParkedRestoreProvider();
      await _pumpPaywall(tester, plansAvailable: true, provider: provider);

      final restoreLabel = _catalogue()['subscription_restore_title'] as String;
      final restoreFinder = find.ancestor(
        of: find.text(restoreLabel),
        matching: find.byWidgetPredicate((w) => w is TextButton),
      );
      expect(restoreFinder, findsOneWidget);
      await tester.tap(restoreFinder);
      await tester.pump();

      final planCards = tester
          .widgetList<InkWell>(find.byType(InkWell))
          .where((w) => w.borderRadius == BorderRadius.circular(18))
          .toList();
      expect(
        planCards,
        isNotEmpty,
        reason: 'harness precondition: plan cards must be built',
      );
      expect(
        planCards.every((card) => card.onTap == null),
        isTrue,
        reason:
            'a concurrent purchase during an in-flight restore is exactly the '
            'double-submit this requirement forbids',
      );

      provider.gate.complete();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    });
  });

}
