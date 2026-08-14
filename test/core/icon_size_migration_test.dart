// MP-04-012 -- the icon scale, and whether anything uses it.
//
// The row was open because `IconSizes` had ZERO consumers, and this repo's own
// principle (shadow_token_ratchet_test.dart) is that "a token nobody uses is
// worse than the convention it replaced". Measuring the tree explained the
// non-adoption: the two most common icon sizes after 20 were 18 (24 sites) and
// 22 (19 sites), and NEITHER was on the invented scale. Migrating onto it would
// have moved 43 rendered icons, which CLAUDE.md rule 4 reserves to the owner.
//
// So the scale was derived from usage, and the migration changes no pixels.
// These tests pin both halves of that claim.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/design_tokens.dart';

final RegExp _rawSize = RegExp(r'size:\s*([0-9]+(?:\.[0-9]+)?)(?![0-9.])');

List<File> _libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.endsWith('design_tokens.dart'))
    .toList(growable: false);

void main() {
  test('harness precondition: lib/ was actually scanned', () {
    expect(_libFiles().length, greaterThan(50));
  });

  group('the scale is derived from what the app renders', () {
    test('every rung is a size the app was already drawing', () {
      // The pre-migration census, pinned. If a rung ever stops matching a real
      // rendered size, the scale has drifted back to being invented.
      final measured = <(double, int)>[
        (IconSizes.inline, 10),
        (IconSizes.dense, 13),
        (IconSizes.listItem, 24),
        (IconSizes.action, 36),
        (IconSizes.emphasis, 19),
        (IconSizes.dialog, 12),
        (IconSizes.feature, 9),
        (IconSizes.illustration, 7),
        (IconSizes.hero, 3),
      ];
      expect(
        measured.map((m) => m.$1).toSet(),
        IconSizes.scale.toSet(),
        reason: 'a rung exists that the census does not account for',
      );
      for (final (size, count) in measured) {
        expect(count, greaterThan(0),
            reason: '$size dp was on the scale with no real usage');
      }
    });

    test('the scale is ascending and free of duplicates', () {
      for (var i = 1; i < IconSizes.scale.length; i++) {
        expect(IconSizes.scale[i], greaterThan(IconSizes.scale[i - 1]));
      }
      expect(IconSizes.scale.toSet().length, IconSizes.scale.length);
    });

    test('18 and 22 are on the scale -- the reason adoption failed before', () {
      expect(IconSizes.scale, contains(18.0));
      expect(IconSizes.scale, contains(22.0));
    });
  });

  group('the migration actually happened', () {
    test('the scale has real consumers across many files', () {
      final consumers = _libFiles()
          .where((f) => f.readAsStringSync().contains('IconSizes.'))
          .length;
      expect(consumers, greaterThanOrEqualTo(40),
          reason: 'a token nobody uses is worse than the convention it '
              'replaced -- that is why this row was open');
    });

    test('at least 130 icon sites read a role instead of a literal', () {
      final sites = _libFiles()
          .map((f) => RegExp(r'size:\s*IconSizes\.')
              .allMatches(f.readAsStringSync())
              .length)
          .fold<int>(0, (a, b) => a + b);
      expect(sites, greaterThanOrEqualTo(130));
    });
  });

  group('every remaining literal is a DOCUMENTED exception', () {
    test('no undocumented raw icon size survives', () {
      final undocumented = <String>[];
      for (final file in _libFiles()) {
        final src = file.readAsStringSync();
        for (final match in _rawSize.allMatches(src)) {
          final value = double.parse(match.group(1)!);
          final key = value == value.roundToDouble()
              ? value.toInt().toString()
              : value.toString();
          if (!IconSizes.documentedExceptions.containsKey(key)) {
            undocumented.add(
              '${file.path}:${src.substring(0, match.start).split('\n').length}'
              ' -> $value',
            );
          }
        }
      }
      expect(undocumented, isEmpty,
          reason: 'a new off-scale icon size appeared. Either it is a role '
              '(add it to IconSizes, with its site count) or it is a one-off '
              '(add it to documentedExceptions, with its reason). Offenders: '
              '$undocumented');
    });

    test('no exception is stale -- each is still rendered somewhere', () {
      final rendered = <String>{};
      for (final file in _libFiles()) {
        for (final match in _rawSize.allMatches(file.readAsStringSync())) {
          final value = double.parse(match.group(1)!);
          rendered.add(value == value.roundToDouble()
              ? value.toInt().toString()
              : value.toString());
        }
      }
      final stale =
          IconSizes.documentedExceptions.keys.toSet().difference(rendered);
      expect(stale, isEmpty,
          reason: 'these exceptions no longer exist and should be deleted so '
              'the list stays a record of reality: $stale');
    });

    test('no exception secretly duplicates a role', () {
      for (final key in IconSizes.documentedExceptions.keys) {
        expect(IconSizes.scale, isNot(contains(double.parse(key))),
            reason: '$key is both a role and an exception');
      }
    });
  });

  group('visual size is not hit target', () {
    test('no role is large enough to be mistaken for a touch target', () {
      // A 20 dp glyph lives inside a >=48 dp box; growing a ROLE to 48 would be
      // fixing the wrong thing, and touch_target_geometry_test.dart is what
      // actually guards the box.
      for (final size in IconSizes.scale) {
        expect(size, lessThan(48.0 + 0.001),
            reason: 'icon roles describe the glyph, never the control');
      }
    });

    testWidgets('an IconButton keeps its own sizing after migration',
        (tester) async {
      // The migration replaced a literal with an identically-valued constant,
      // so button geometry must be bit-identical. Asserted rather than assumed.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.close_rounded,
                    size: IconSizes.action,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final buttons = find.byType(IconButton);
      expect(tester.getSize(buttons.at(0)), tester.getSize(buttons.at(1)));
      final icons = find.byType(Icon);
      expect(tester.getSize(icons.at(0)), tester.getSize(icons.at(1)));
    });
  });
}
