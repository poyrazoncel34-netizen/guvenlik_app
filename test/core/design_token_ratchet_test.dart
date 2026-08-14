// MP-04-001 / 005-013 — the design token system, and the thing that makes it
// real rather than decorative.
//
// A token file nobody enforces is documentation that rots. This is a RATCHET,
// modelled on `source_file_size_ratchet_test.dart`, which is how this
// repository already handles accepted debt:
//
//   * every scale is enumerated from `lib/core/design_tokens.dart`, so the
//     test cannot drift from the tokens it claims to enforce;
//   * off-scale values are counted across lib/ and the current count is PINNED;
//   * the count may fall, never rise.
//
// It deliberately does NOT demand a big-bang migration. Rewriting 131 literals
// across 40 screens would churn hundreds of lines and risk exactly the visual
// regressions CLAUDE.md rule 4 exists to prevent, on a codebase whose review
// model depends on small diffs. Freezing the debt is the honest move: new code
// lands on the scale, existing drift is recorded in a number instead of being
// hidden behind a token file that nothing checks.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/design_tokens.dart';

/// Measured 2026-08-13 against the committed tree, immediately after the token
/// file was introduced. Lowering these is progress; raising one means new
/// off-scale values were added and should have used a token.
const Map<String, int> acceptedOffScale = <String, int>{
  'radius': 28,
  'spacing': 30,
  // 73 -> 23 after the MP-04-012 migration. TIGHTENED rather than left high:
  // a pin far above reality stops catching the drift it exists to catch. The
  // 23 that remain are exactly IconSizes.documentedExceptions, and
  // icon_size_migration_test.dart fails if a NEW one appears or a listed one
  // goes stale.
  'icon': 23,
  'fontSize': 77,
};

/// Raw `Color(0x...)` literals outside the palette. Pinned rather than zero
/// because a handful are legitimately local (the light-on-white legal notice,
/// the Android system bar colours in main.dart) -- but a NEW one is almost
/// always a colour that should have been a semantic token.
const int acceptedRawColorLiterals = 30;

typedef _Scan = ({String kind, RegExp pattern, Set<double> allowed});

void main() {
  // Built FROM the token file. If a rung is added or removed there, this test
  // follows automatically instead of silently disagreeing.
  final scans = <_Scan>[
    (
      kind: 'radius',
      pattern: RegExp(r'BorderRadius\.circular\((\d+(?:\.\d+)?)\)'),
      allowed: Radii.scale.toSet(),
    ),
    (
      kind: 'spacing',
      pattern: RegExp(r'EdgeInsets\.all\((\d+(?:\.\d+)?)\)'),
      allowed: Spacing.scale.toSet(),
    ),
    (
      kind: 'icon',
      pattern: RegExp(r'\bsize:\s*(\d+(?:\.\d+)?)\b'),
      allowed: IconSizes.scale.toSet(),
    ),
    (
      kind: 'elevation',
      pattern: RegExp(r'elevation:\s*(\d+(?:\.\d+)?)'),
      allowed: Elevation.scale.toSet(),
    ),
    (
      kind: 'fontSize',
      pattern: RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)'),
      allowed: TypeScale.scale.toSet(),
    ),
  ];

  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('the token scales are non-empty and strictly ascending', () {
    // Harness precondition. A scale that silently became empty would allow
    // everything and make every count below zero.
    for (final scale in <List<double>>[
      Spacing.scale,
      Radii.scale,
      Elevation.scale,
      IconSizes.scale,
    ]) {
      expect(scale, isNotEmpty);
      for (var i = 1; i < scale.length; i++) {
        expect(
          scale[i],
          greaterThan(scale[i - 1]),
          reason: 'scale $scale is not ascending',
        );
      }
    }
  });

  test('off-scale design values do not increase', () {
    final files = dartFiles();
    expect(
      files.length,
      greaterThan(50),
      reason: 'harness precondition: lib/ must actually have been scanned',
    );

    final counts = <String, int>{};
    final examples = <String, List<String>>{};
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final scan in scans) {
        for (final match in scan.pattern.allMatches(source)) {
          final value = double.parse(match.group(1)!);
          if (scan.allowed.contains(value)) continue;
          counts[scan.kind] = (counts[scan.kind] ?? 0) + 1;
          (examples[scan.kind] ??= <String>[])
              .add('${file.path}: ${match.group(0)}');
        }
      }
    }

    for (final scan in scans) {
      final actual = counts[scan.kind] ?? 0;
      final accepted = acceptedOffScale[scan.kind] ?? 0;
      expect(
        actual,
        lessThanOrEqualTo(accepted),
        reason:
            'Off-scale ${scan.kind} values rose from $accepted to $actual. Use '
            'a token from lib/core/design_tokens.dart. First offenders: '
            '${(examples[scan.kind] ?? const <String>[]).take(5).join(", ")}',
      );
      if (actual < accepted) {
        // Not a failure — a prompt to bank the progress so it cannot regress.
        // ignore: avoid_print
        print(
          'RATCHET: ${scan.kind} improved $accepted -> $actual; lower the '
          'pinned value in acceptedOffScale.',
        );
      }
    }
  });

  test('elevation is fully on-scale and stays that way', () {
    // The one scale that had no debt when the tokens landed. Pinned at zero so
    // a new elevation value is a deliberate decision, not a drive-by.
    var offScale = 0;
    for (final file in dartFiles()) {
      for (final match in RegExp(
        r'elevation:\s*(\d+(?:\.\d+)?)',
      ).allMatches(file.readAsStringSync())) {
        if (!Elevation.scale.contains(double.parse(match.group(1)!))) {
          offScale++;
        }
      }
    }
    expect(offScale, 0);
  });

  test('the theme itself is built from tokens, not literals', () {
    // This is what makes the token file load-bearing rather than decorative:
    // the single place that defines shapes for every themed component reads it.
    final theme = File('lib/core/app_theme.dart').readAsStringSync();
    expect(theme, contains("import 'design_tokens.dart';"));
    expect(theme, contains('Radii.'));
    expect(theme, contains('Elevation.'));
    expect(theme, contains('Spacing.'));
    expect(
      RegExp(r'elevation:\s*\d').hasMatch(theme),
      isFalse,
      reason: 'a numeric elevation in the theme bypasses the scale',
    );
  });

  test('breakpoints and density match the checks the screens actually make',
      () {
    // The scale was derived from home_page.dart's existing thresholds. This
    // test used to assert those thresholds were still written out INLINE there
    // -- which was correct while nothing consumed the tokens, and became exactly
    // backwards once home_page was migrated onto them: the assertion demanded
    // that the duplication survive.
    //
    // What matters now is that home_page CONSUMES the scale, so the tokens and
    // the layout cannot disagree by construction.
    final home = File('lib/screens/home_page.dart').readAsStringSync();
    expect(home, contains('DensityTokens.horizontalPadding(size)'));
    expect(home, contains('DensityTokens.gap(density)'));
    expect(home, contains('DensityTokens.sectionGap(density)'));
    expect(home, contains('Breakpoints.isShort('));
    expect(
      home.contains('size.width > 400'),
      isFalse,
      reason: 'the inline threshold must not come back alongside the token',
    );

    expect(Breakpoints.wideWidth, 400);
    expect(Breakpoints.narrowWidth, 340);
    expect(Breakpoints.shortHeight, 700);

    expect(DensityTokens.of(const Size(400, 640)), Density.compact);
    expect(DensityTokens.of(const Size(400, 900)), Density.comfortable);
    expect(DensityTokens.horizontalPadding(const Size(430, 900)), Spacing.xl);
    expect(DensityTokens.horizontalPadding(const Size(360, 900)), Spacing.lg);
    expect(DensityTokens.horizontalPadding(const Size(320, 900)), Spacing.md);
  });

  test('motion tokens are not duplicated here', () {
    // Motion has its own documented file; two timing scales would be worse
    // than one.
    final tokens =
        File('lib/core/design_tokens.dart').readAsStringSync();
    expect(
      tokens,
      isNot(contains('Duration(milliseconds:')),
      reason: 'durations belong in motion.dart',
    );
    expect(File('lib/core/motion.dart').existsSync(), isTrue);
  });

  test('font weights stay on the four-weight scale', () {
    final used = <String>{};
    for (final file in dartFiles()) {
      for (final match in RegExp(
        r'FontWeight\.(w\d00|bold|normal)',
      ).allMatches(file.readAsStringSync())) {
        used.add(match.group(1)!);
      }
    }
    expect(
      used,
      isNotEmpty,
      reason: 'harness precondition: weights must actually be in use',
    );
    const allowed = {'w500', 'w600', 'w700', 'w800', 'w900'};
    expect(
      used.difference(allowed),
      isEmpty,
      reason:
          'TypeScale names exactly the weights in use. `bold`/`normal` aliases '
          'and stray w100..w400 make the type system unreadable.',
    );
  });

  test('colour literals outside the palette do not increase', () {
    var raw = 0;
    final examples = <String>[];
    for (final file in dartFiles()) {
      if (file.path.endsWith('app_colors.dart')) continue;
      for (final match in RegExp(
        r'Color\(0x[0-9A-Fa-f]{8}\)',
      ).allMatches(file.readAsStringSync())) {
        raw++;
        if (examples.length < 5) examples.add('${file.path}: ${match.group(0)}');
      }
    }
    expect(
      raw,
      lessThanOrEqualTo(acceptedRawColorLiterals),
      reason:
          'Raw colour literals rose to $raw. Safety-state colours in '
          'particular must come from AppColors (emergency/success/warning/info) '
          'so a palette change cannot leave one screen on the old red. '
          'Offenders: ${examples.join(", ")}',
    );
  });

  test('safety-state colours are semantic and used semantically', () {
    final palette = File('lib/core/app_colors.dart').readAsStringSync();
    for (final name in const [
      'emergency',
      'success',
      'warning',
      'info',
    ]) {
      expect(
        palette,
        contains('static const Color $name'),
        reason: 'the safety states must be NAMED, not raw hex at call sites',
      );
    }
    // And they are the ones the emergency surfaces actually reach for.
    final panic = File('lib/widgets/panic_button.dart').readAsStringSync();
    expect(panic, contains('AppColors.emergency'));
    final readiness =
        File('lib/core/widgets/readiness_card.dart').readAsStringSync();
    expect(readiness, contains('AppColors.success'));
    expect(readiness, contains('AppColors.warning'));
  });

  test('there is exactly one loading idiom besides the splash shimmer', () {
    // MP-04-024: the "skeleton standard" for this app is deliberately narrow --
    // a bounded spinner everywhere, and a shimmer ONLY on the splash, where
    // there is nothing yet to lay a skeleton over. A third idiom appearing is
    // the drift this pins.
    final shimmerFiles = <String>[];
    for (final file in dartFiles()) {
      // The palette DEFINES the shimmer colours; it does not implement the
      // idiom. Excluded so this measures widgets, not a comment.
      if (file.path.endsWith('app_colors.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains('Shimmer') || source.contains('_buildShimmerText')) {
        shimmerFiles.add(file.path);
      }
    }
    expect(
      shimmerFiles,
      <String>['lib/screens/splash_screen.dart'],
      reason:
          'Shimmer is the splash-only idiom. Everywhere else uses a bounded '
          'CircularProgressIndicator; see docs/design/design_system.md.',
    );
  });

}
