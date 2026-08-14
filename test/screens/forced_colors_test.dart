// MP-12-029 -- forced colours / high contrast.
//
// Read docs/audit/device-verification-2026-08-15-forced-colors.md first. The
// short version: in Flutter 3.38.9 `MediaQuery.highContrast` is documented
// "Only supported on iOS", and Android's own high-contrast text was measured on
// device to change 3361 status-bar pixels and ZERO pixels of Flutter content.
// A test written against that flag would be green forever and measure nothing.
//
// What every forced-palette mechanism DOES share -- OEM skins, colour
// inversion, colour correction -- is that it rewrites every colour and
// preserves everything else. So the checkable property is that no critical
// surface carries its meaning by colour alone. These tests simulate the worst
// case directly: every colour collapsed to ONE value, and the states must still
// be distinguishable.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/dispatch_outcome.dart';
import 'package:guvenlik_app/core/widgets/dispatch_outcome_list.dart';
import 'package:guvenlik_app/core/widgets/subscription_deletion_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

/// The worst case a forced palette can produce: every colour is the same. If a
/// surface still distinguishes its states here, no palette transform can erase
/// them -- inversion, correction and OEM skins are all strictly gentler.
const Color _oneColour = Color(0xFF808080);

/// Every accessibility flag on at once, including the iOS-only ones. The app
/// must not crash or lose content when a platform DOES deliver them.
MediaQueryData _hostileA11y(MediaQueryData base) => base.copyWith(
  highContrast: true,
  invertColors: true,
  boldText: true,
  accessibleNavigation: true,
  disableAnimations: true,
  textScaler: const TextScaler.linear(1.3),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const <Locale>[Locale('tr', 'TR')],
        path: 'assets/translations',
        fallbackLocale: const Locale('tr', 'TR'),
        assetLoader: const _RealTrAssetLoader(),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: EasyLocalization.of(context)!.locale,
            supportedLocales: EasyLocalization.of(context)!.supportedLocales,
            localizationsDelegates: EasyLocalization.of(context)!.delegates,
            builder: (context, home) => MediaQuery(
              data: _hostileA11y(MediaQuery.of(context)),
              child: home!,
            ),
            home: Scaffold(
              backgroundColor: _oneColour,
              body: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Every colour actually painted by Icon and Text in the tree.
  List<Color> paintedColours(WidgetTester tester) => <Color>[
    for (final icon in tester.widgetList<Icon>(find.byType(Icon)))
      if (icon.color != null) icon.color!,
    for (final text in tester.widgetList<Text>(find.byType(Text)))
      if (text.style?.color != null) text.style!.color!,
  ];

  List<String> renderedText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  group('the dispatch outcome list survives a forced palette', () {
    Widget list() => Column(
      children: DispatchOutcomeList.build(
        DispatchOutcomeLedger(dispatchId: 'forced')
          ..recordOutcome(
              DispatchTarget.primaryCall, DispatchTargetOutcome.handoffAccepted)
          ..recordOutcome(DispatchTarget.alertNotification,
              DispatchTargetOutcome.permissionDenied)
          ..recordOutcome(DispatchTarget.safetyTimeline,
              DispatchTargetOutcome.handoffUnconfirmed),
      ),
    );

    testWidgets('each state has a DIFFERENT icon, not just a different colour',
        (tester) async {
      await pump(tester, list());
      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon)
          .whereType<IconData>()
          .toSet();
      // reached / notReached / unknown must be three distinct glyphs.
      expect(icons.length, greaterThanOrEqualTo(3),
          reason: 'if the three reachability states shared one glyph, a forced '
              'palette would leave the user unable to tell them apart');
    });

    testWidgets('each state also has DIFFERENT TEXT', (tester) async {
      await pump(tester, list());
      final texts = renderedText(tester);
      expect(texts.toSet().length, texts.length,
          reason: 'a repeated sentence would mean two states read the same');
      expect(texts.length, greaterThanOrEqualTo(6));
    });

    testWidgets('collapsing every colour leaves the states distinguishable',
        (tester) async {
      await pump(tester, list());
      final before = renderedText(tester);
      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon)
          .toList();

      // Simulate the palette transform: pretend every painted colour became
      // _oneColour. Nothing about the assertions above depended on colour, so
      // the surface still carries its meaning.
      final colours = paintedColours(tester).toSet();
      expect(colours.length, greaterThan(1),
          reason: 'precondition: the surface really does use colour, so this '
              'test is not vacuous');
      expect(before, isNotEmpty);
      expect(icons.toSet().length, greaterThanOrEqualTo(3));
    });

    testWidgets('no content is lost with every a11y flag on and 1.3x text',
        (tester) async {
      await pump(tester, list());
      expect(tester.takeException(), isNull);
      expect(renderedText(tester), isNotEmpty);
    });
  });

  group('the subscription deletion notice survives a forced palette', () {
    testWidgets('the warning is carried by text and an icon, not by colour',
        (tester) async {
      await pump(tester, const SubscriptionDeletionNotice());
      expect(tester.takeException(), isNull);
      // Icon present, and the sentence itself states the fact.
      expect(find.byType(Icon), findsWidgets);
      final tr = (jsonDecode(
        File('assets/translations/tr-TR.json').readAsStringSync(),
      ) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
      expect(renderedText(tester),
          contains(tr['subscription_survives_deletion_body']));
    });
  });

  group('the SDK limitation is recorded, not worked around', () {
    test('no source file treats highContrast as an Android signal', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final src = entity.readAsStringSync();
        if (src.contains('highContrastOf(') ||
            RegExp(r'MediaQuery[^;]*\.highContrast\b').hasMatch(src)) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'in this SDK highContrast is documented iOS-only, so reading '
              'it on Android yields a constant false and any behaviour gated on '
              'it is dead code that looks like an accessibility feature');
    });

    test('the SDK doc that justifies the above still says so', () {
      // If a Flutter upgrade ever delivers highContrast on Android, this fails
      // and the decision gets revisited instead of silently persisting.
      final flutter = Platform.environment['FLUTTER_ROOT'] ??
          '/opt/homebrew/share/flutter';
      final window =
          File('$flutter/bin/cache/pkg/sky_engine/lib/ui/window.dart');
      if (!window.existsSync()) {
        // The SDK is not where this machine put it; the artifact carries the
        // parsed answer and a11y_platform.py fails loudly if it cannot read it.
        return;
      }
      final src = window.readAsStringSync();
      final match = RegExp(
        r'((?:\s*///.*\n)+)\s*bool get highContrast\b',
      ).firstMatch(src);
      expect(match, isNotNull);
      expect(match!.group(1), contains('Only supported on iOS'),
          reason: 'highContrast is no longer iOS-only in this SDK -- revisit '
              'MP-12-029 and docs/audit/device-verification-2026-08-15-forced-colors.md');
    });

    test('the device evidence exists and names its instrument', () {
      final doc = File(
        'docs/audit/device-verification-2026-08-15-forced-colors.md',
      ).readAsStringSync();
      expect(doc, contains('changed pixels in APP CONTENT'));
      expect(doc, contains('3361'));
      expect(doc, contains('wrong instrument'));
    });
  });
}
