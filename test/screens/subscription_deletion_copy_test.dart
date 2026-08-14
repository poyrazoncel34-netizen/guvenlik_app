// MP-23-015 -- a subscriber deleting their local data must be told that a
// Google Play subscription survives it.
//
// Tested against the REAL tr-TR catalogue, so the assertions are about the
// sentence a Turkish user actually reads and not about a key existing.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/widgets/subscription_deletion_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

Map<String, String> _catalogue(String locale) =>
    (jsonDecode(File('assets/translations/$locale.json').readAsStringSync())
            as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v.toString()));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  group('the copy itself', () {
    test('Turkish says the subscription is NOT cancelled, and names Play', () {
      final tr = _catalogue('tr-TR');
      final body = tr['subscription_survives_deletion_body']!;
      expect(body, contains('Google Play'));
      expect(body.toLowerCase(), contains('iptal'));
      expect(body.toLowerCase(), contains('abonel'));
      // The claim must be the NEGATIVE one. "iptal edin" alone would read as
      // an instruction, not as a warning that deletion is not cancellation.
      expect(body, contains('iptal etmez'));
      expect(tr['subscription_survives_deletion_title'], contains('iptal olmaz'));
    });

    test('Turkish also covers UNINSTALL, not only in-app deletion', () {
      // Play's own policy language is about uninstalling; a user who reads
      // only "deleting data" may still believe removing the app cancels it.
      final body = _catalogue('tr-TR')['subscription_survives_deletion_body']!;
      expect(body.toLowerCase(), contains('kaldırmak'));
    });

    test('English carries the same three facts', () {
      final en = _catalogue('en-US');
      final body = en['subscription_survives_deletion_body']!;
      expect(body, contains('Google Play'));
      expect(body.toLowerCase(), contains('does not cancel'));
      expect(body.toLowerCase(), contains('uninstall'));
    });

    test('the copy stays short enough to be read at a delete prompt', () {
      for (final locale in <String>['tr-TR', 'en-US']) {
        final body = _catalogue(locale)['subscription_survives_deletion_body']!;
        expect(body.length, lessThan(280), reason: locale);
      }
    });
  });

  group('the notice widget', () {
    Future<void> pump(WidgetTester tester, {bool compact = false}) async {
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
              home: Scaffold(
                body: SubscriptionDeletionNotice(compact: compact),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    List<String> rendered(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    testWidgets('renders the real sentence, not a key', (tester) async {
      final tr = _catalogue('tr-TR');
      await pump(tester);
      final texts = rendered(tester);
      expect(texts, contains(tr['subscription_survives_deletion_title']));
      expect(texts, contains(tr['subscription_survives_deletion_body']));
      expect(texts, contains(tr['subscription_survives_deletion_action']));
      final leaked = texts
          .where((d) => RegExp(r'^[a-z0-9]+(_[a-z0-9]+){2,}$').hasMatch(d))
          .toList();
      expect(leaked, isEmpty);
    });

    testWidgets('the compact variant keeps the sentence', (tester) async {
      final tr = _catalogue('tr-TR');
      await pump(tester, compact: true);
      expect(rendered(tester),
          contains(tr['subscription_survives_deletion_body']));
    });

    testWidgets('the management action clears 48 dp', (tester) async {
      await pump(tester);
      final rect = tester.getRect(find.byType(InkWell).first);
      expect(rect.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('the action is one screen-reader node', (tester) async {
      final tr = _catalogue('tr-TR');
      await pump(tester);
      expect(
        find.bySemanticsLabel(tr['subscription_survives_deletion_action']!),
        findsOneWidget,
      );
    });
  });

  group('it appears on every path that erases local data', () {
    test('the data-deletion screen shows it on the page AND in the dialog', () {
      final src = File('lib/screens/settings_legal/data_deletion_screen.dart')
          .readAsStringSync();
      expect('SubscriptionDeletionNotice('.allMatches(src), hasLength(2),
          reason: 'the page lists what is erased and the dialog is the last '
              'stop before the PIN step; both are places a subscriber decides');
      expect(src, contains('SubscriptionDeletionNotice(compact: true)'));
    });

    test('the reset dialog shows it too', () {
      final src =
          File('lib/core/utils/app_reset_helper.dart').readAsStringSync();
      expect(src, contains('SubscriptionDeletionNotice(compact: true)'));
    });

    test('it does NOT offer to cancel, because the app cannot', () {
      final src = File('lib/core/widgets/subscription_deletion_notice.dart')
          .readAsStringSync();
      expect(src, contains(RegExp(r'googlePlaySubscriptionsUrl')));
      for (final impossible in <String>['cancelSubscription', 'Purchases.cancel']) {
        expect(src, isNot(contains(impossible)),
            reason: 'a control that looked like it could cancel would be a '
                'worse lie than the silence this row is about');
      }
    });

    test('the link points at the Play subscriptions screen for THIS package',
        () {
      expect(AppConstants.googlePlaySubscriptionsUrl,
          contains('play.google.com/store/account/subscriptions'));
      expect(AppConstants.googlePlaySubscriptionsUrl,
          contains('com.poyrazoncel.korubeni'));
    });
  });
}
