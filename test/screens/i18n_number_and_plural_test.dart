// MP-14-005..009 / MP-14-014 — number, currency and plural correctness.
//
// The honest position for this app, asserted rather than asserted-about:
//
//   * It formats NO currency of its own. The only price shown comes from
//     `StoreProduct.priceString`, which Google Play has already formatted in
//     the user's locale and currency.
//   * It formats no grouped or high-precision numbers. The single decimal in
//     the product is the map's coordinate readout, where a dot separator is the
//     geographic convention and a locale-swapped comma would be wrong.
//   * It does not implement pluralisation because it does not need to: Turkish
//     (the shipped runtime locale) does not inflect a noun after a numeral, and
//     every count-bearing English string is structurally unreachable in its
//     singular form.
//
// Each of those claims is a guard, and each guard is pinned here — so the rows
// that depend on them cannot quietly become false.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _catalogue(String locale) =>
    jsonDecode(File('assets/translations/$locale.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('MP-14-005: currency is never formatted by this app', () {
    test('the paywall renders the store-formatted price string verbatim', () {
      final source =
          File('lib/screens/subscription/paywall_screen.dart').readAsStringSync();
      expect(
        source,
        contains('package.storeProduct.priceString'),
        reason:
            'Prices must come pre-formatted from Play, which is what makes '
            'them locale- and currency-correct without this app owning any '
            'currency logic.',
      );
      expect(
        source,
        isNot(contains('NumberFormat')),
        reason: 'formatting a price locally would break locale correctness',
      );
      // And an empty/absent price is handled rather than rendered blank.
      expect(source, contains('subscription_price_unavailable'));
    });
  });

  group('MP-14-006..008: the app formats no grouped or high-precision numbers',
      () {
    test('no NumberFormat / intl number formatting exists in lib/', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains('NumberFormat')) {
          offenders.add('${entity.path}: NumberFormat');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'If this ever goes red the app has started formatting numbers '
            'itself, and MP-14-006/007/008 must be re-evaluated as APPLICABLE '
            'rather than resting on this guard.',
      );
    });

    test('the only decimal readout is the map coordinate, deliberately dotted',
        () {
      final decimalSites = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains('toStringAsFixed')) decimalSites.add(entity.path);
      }
      expect(
        decimalSites,
        <String>['lib/screens/map_page.dart'],
        reason:
            'Latitude/longitude are conventionally dot-separated and are a '
            'technical readout, not a localized quantity. A NEW decimal site '
            'elsewhere would be a real locale question.',
      );
    });
  });

  group('MP-14-009: the singular case of every count-bearing string is '
      'unreachable', () {
    test('both catalogues agree on which strings carry a count', () {
      final tr = _catalogue('tr-TR');
      final en = _catalogue('en-US');
      String countKeys(Map<String, dynamic> c) => (c.entries
              .where((e) => e.value is String && (e.value as String).contains('{count}'))
              .map((e) => e.key)
              .toList()
            ..sort())
          .join(',');
      expect(countKeys(tr), countKeys(en));
      // Harness precondition: there must BE count-bearing strings, or the
      // reachability assertions below prove nothing.
      expect(countKeys(tr), isNotEmpty);
    });

    test('the readiness card routes count==1 to a separate singular string',
        () {
      final source =
          File('lib/core/widgets/readiness_card.dart').readAsStringSync();
      // "1 steps left in setup" is only avoided because of this branch.
      expect(
        RegExp(r'missing\.length == 1').hasMatch(source),
        isTrue,
        reason: 'the singular branch is what keeps setup_incomplete at >= 2',
      );
      final singularIdx = source.indexOf('readiness_almost_title');
      final pluralIdx = source.indexOf('setup_incomplete');
      expect(singularIdx, isNot(-1));
      expect(pluralIdx, isNot(-1));
      expect(
        singularIdx,
        lessThan(pluralIdx),
        reason:
            'the singular case must be handled BEFORE falling through to the '
            'count-bearing string',
      );
      expect(
        _catalogue('en-US')['setup_incomplete'] as String,
        contains('steps'),
        reason:
            'this string is plural-only by design; if it is ever reworded to '
            'cover 1 it needs a real plural form',
      );
    });

    test('the notification group summary only fires above one', () {
      final source = File(
        'lib/core/services/notification_service.dart',
      ).readAsStringSync();
      expect(
        source,
        contains('if (_activeNotificationCount > 1) {'),
        reason:
            '"1 notifications" is only unreachable because of this guard',
      );
      final guardIdx = source.indexOf('if (_activeNotificationCount > 1) {');
      final callIdx = source.indexOf('_showGroupSummary();', guardIdx);
      expect(
        callIdx,
        isNot(-1),
        reason: 'the summary call must sit inside that guard',
      );
      expect(callIdx - guardIdx, lessThan(120));
    });

    test('Turkish needs no plural form after a numeral', () {
      // Not a code property -- a linguistic one, recorded so the next reader
      // does not "fix" it by adding plural machinery. Turkish nouns are not
      // inflected for number after a numeral: "1 adım", "3 adım".
      final tr = _catalogue('tr-TR');
      expect(tr['setup_incomplete'] as String, contains('{count} adım'));
      expect(
        (tr['setup_incomplete'] as String).contains('adımlar'),
        isFalse,
        reason: 'a pluralised Turkish noun after a numeral would be incorrect',
      );
    });
  });

  group('MP-14-014: long-translation resilience', () {
    test('no user-facing string exceeds the length the layouts were built for',
        () {
      // The real risk is a translation that is dramatically longer than its
      // Turkish original. Both catalogues ship together, so the ratio is
      // measurable rather than hypothetical.
      final tr = _catalogue('tr-TR');
      final en = _catalogue('en-US');
      final wild = <String>[];
      for (final entry in tr.entries) {
        final trValue = entry.value;
        final enValue = en[entry.key];
        if (trValue is! String || enValue is! String) continue;
        // Two conditions, both required. The RATIO alone is meaningless on a
        // short label ("Acil kişi seç" -> "Select emergency contact" is 1.8x
        // and fits anywhere); the ABSOLUTE length alone would flag every long
        // paragraph that was always long. Overflow needs both: a string that is
        // long AND much longer than the layout was designed around.
        if (trValue.length < 12) continue;
        if (enValue.length > 40 && enValue.length > trValue.length * 1.8) {
          wild.add('${entry.key}: tr=${trValue.length} en=${enValue.length}');
        }
      }
      expect(
        wild,
        isEmpty,
        reason:
            'A translation nearly twice its original length is the case that '
            'overflows a fixed-height card. Shorten it or give the layout '
            'room, then re-run.',
      );
    });
  });
}
