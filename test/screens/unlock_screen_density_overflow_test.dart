// MP-72-001 / MP-72-015 -- layout at large Android display sizes and text sizes.
//
// The audit carried these two rows as FAIL with the root cause NOT established:
// a wrong `minHeight` had been found and fixed on the unlock screen, but the
// negative control that was tried could not reproduce the overflow from it, so
// nobody could say the fix addressed the real cause. This file settles both
// halves, and the first half is a correction rather than a confirmation.
//
// FINDING 1 -- THE `minHeight` HYPOTHESIS WAS WRONG, AND HERE IS WHY.
// A `ConstrainedBox(minHeight: tooTall)` inside a `SingleChildScrollView`
// CANNOT produce a RenderFlex overflow. The scroll view gives its child an
// unbounded vertical constraint, so an over-tall child simply becomes
// scrollable content. The first case below asserts exactly that, so the next
// person does not spend the same time re-testing a hypothesis that is
// structurally impossible. (The `minHeight` fix was still correct -- it stopped
// the column being forced past the viewport -- it just was not the source of
// the *overflow* message.)
//
// FINDING 2 -- THE REAL OVERFLOW.
// On an API 36 emulator at `wm density 560` with `font_scale 2.0`, the consent
// screen logged "A RenderFlex overflowed by 82 pixels on the right". The
// offending widget was pinned down by scanning screenshots for Flutter's yellow
// overflow stripe and reading the label off the render: the Terms version line,
// `ⓘ Sürüm 3.1.0 — 21 Mayıs 2026`, whose Row had no Expanded. Its KVKK twin
// thirty lines away already had one, which is why a source read had missed it.
//
// The harness matrix below then widened the finding: EITHER a large display
// size OR maximum text scaling reproduces it on its own. The absolute pixel
// counts here are larger than the device's 82 px because this harness renders
// the row without the surrounding card's width constraints -- it reproduces the
// CLASS of failure, while the 82 px is the shipped magnitude on the real
// screen.
// The offending widget was identified by scanning screenshots for Flutter's
// yellow overflow stripe and reading the label off the render: the Terms
// version line, `ⓘ Sürüm 3.1.0 — 21 Mayıs 2026`, in a Row whose Text had no
// Expanded. Its KVKK twin thirty lines away already had one -- which is why a
// source read had not caught it either.
//
// Device numbers: 1080 x 2400 at density 560 is dpr 3.5, i.e. 308.6 x 685.7
// LOGICAL pixels. The app clamps text scaling at 2.0 (`appTextScaler`), so 2.0
// is the worst case a user can actually reach, not an invented one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Logical viewport of the reproducing device: 1080 x 2400 at dpr 3.5.
const Size kDensity560Viewport = Size(308.6, 685.7);

/// The app's own ceiling, from `appTextScaler` in lib/main.dart.
const double kMaxTextScale = 2.0;

Future<void> pumpStressed(
  WidgetTester tester,
  Widget child, {
  Size size = kDensity560Viewport,
  double textScale = kMaxTextScale,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      // copyWith, NOT a fresh MediaQueryData: constructing one from scratch
      // resets `size` to Size.zero, so widgets that measure themselves against
      // MediaQuery.size lay out against nothing and the matrix below reports
      // whichever cell happened to run first. That harness bug produced a
      // 43 px "overflow" for a cell that is actually clean; it is fixed here
      // and called out so the numbers in this file are trustworthy.
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// A Column forced four times taller than the viewport, to show that an
/// over-tall `minHeight` inside a scroll view becomes scroll extent rather than
/// a RenderFlex overflow.
class _OverTallColumn extends StatelessWidget {
  const _OverTallColumn();

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 2800),
        // Deliberately not const: the point of the case is that this Column
        // really is laid out inside the over-tall box.
        // ignore: prefer_const_constructors
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[SizedBox(height: 200, width: 100)],
        ),
      );
}

/// The version line, with and without the Expanded that was missing.
class _VersionLine extends StatelessWidget {
  const _VersionLine({required this.flexible});

  final bool flexible;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline_rounded, size: 14),
          const SizedBox(width: 6),
          // The single line under test: with Expanded it wraps, without it the
          // Row is asked for more width than it has.
          if (flexible)
            const Expanded(
              child: Text(
                'Sürüm 3.1.0 — 21 Mayıs 2026',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            )
          else
            const Text(
              'Sürüm 3.1.0 — 21 Mayıs 2026',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

void main() {
  group('FINDING 1: the minHeight hypothesis cannot produce an overflow', () {
    testWidgets(
        'an over-tall ConstrainedBox inside a scroll view scrolls, it does not '
        'overflow', (tester) async {
      await pumpStressed(
        tester,
        // Deliberately absurd: four times the viewport height.
        const _OverTallColumn(),
        textScale: 1.0,
      );
      expect(
        tester.takeException(),
        isNull,
        reason:
            'RECORDED SO IT IS NOT RE-TESTED: a SingleChildScrollView hands its '
            'child an UNBOUNDED vertical constraint, so an over-tall minHeight '
            'becomes scroll extent, never a RenderFlex overflow. The earlier '
            'negative control failed to reproduce the overflow for this reason, '
            'not because the reproduction was set up wrong.',
      );
    });
  });

  group('FINDING 2: the version line overflows whenever width gets tight', () {
    testWidgets('NEGATIVE CONTROL: without Expanded it overflows', (
      tester,
    ) async {
      await pumpStressed(tester, const _VersionLine(flexible: false));
      final Object? error = tester.takeException();
      expect(
        error,
        isNotNull,
        reason:
            'This is the shipped defect, measured on device as "overflowed by '
            '82 pixels on the right". If this case goes green the reproduction '
            'has stopped reproducing and the fix below proves nothing.',
      );
      expect(error.toString(), contains('overflowed'));
    });

    testWidgets('with Expanded the same line wraps instead', (tester) async {
      await pumpStressed(tester, const _VersionLine(flexible: true));
      expect(
        tester.takeException(),
        isNull,
        reason:
            'The version string is legal provenance -- which text did the user '
            'accept -- so it must wrap and stay readable rather than clip or '
            'ellipsise.',
      );
    });

    // MEASURED MATRIX. Each cell is its own test on purpose: four pumps in a
    // single test drain `takeException()` against each other and produced
    // contradictory readings (one cell reported 43 px in one ordering and
    // clean in another). One pump per test is the only ordering-independent
    // way to read this.
    //
    //   viewport                     text scale   result
    //   411.4 x 914.3  (default)     1.0          clean
    //   411.4 x 914.3  (default)     2.0          overflow
    //   308.6 x 685.7  (density 560) 1.0          overflow
    //   308.6 x 685.7  (density 560) 2.0          overflow
    //
    // EITHER axis alone is enough; only the shipping default is clean. That is
    // why every walkthrough at the default density and text size passed while
    // the defect was live -- and it moves this from "large-display edge case"
    // to "anyone at maximum font size, on any screen".
    const Size kDefaultViewport = Size(411.4, 914.3); // dpr 2.625

    testWidgets('CONTROL: the shipping default is clean', (tester) async {
      await pumpStressed(
        tester,
        const _VersionLine(flexible: false),
        size: kDefaultViewport,
        textScale: 1.0,
      );
      expect(
        tester.takeException(),
        isNull,
        reason:
            'The one clean cell, and the reason the defect survived every '
            'default-configuration walkthrough.',
      );
    });

    testWidgets('NEGATIVE CONTROL: default size, text scale at the app ceiling',
        (tester) async {
      await pumpStressed(
        tester,
        const _VersionLine(flexible: false),
        size: kDefaultViewport,
        textScale: kMaxTextScale,
      );
      final Object? error = tester.takeException();
      expect(error, isNotNull, reason: 'text scaling alone reproduces it');
      expect(error.toString(), contains('overflowed'));
    });

    testWidgets('NEGATIVE CONTROL: density 560, normal text scale', (
      tester,
    ) async {
      await pumpStressed(
        tester,
        const _VersionLine(flexible: false),
        textScale: 1.0,
      );
      final Object? error = tester.takeException();
      expect(error, isNotNull, reason: 'display size alone reproduces it too');
      expect(error.toString(), contains('overflowed'));
    });
  });
}
