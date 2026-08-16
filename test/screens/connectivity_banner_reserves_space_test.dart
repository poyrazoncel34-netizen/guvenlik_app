// The offline banner must not sit on top of the page it warns about.
//
// Found on device, not in review (2026-08-16, MP-72-031). The banner is a
// `Positioned(top: 0)` overlay in the shell's Stack, so it occupies no layout
// space. Measured on an API 36 emulator: with the banner visible the top ~42 dp
// of every tab was covered, which on Home hid more than half of the
// "Hos Geldiniz" heading; with the banner absent the same heading, at the same
// scroll position, rendered in full. Every earlier walkthrough ran online, so
// the banner never appeared and the overlap was never seen.
//
// The fix reserves the banner's height in the shell. What this test pins is the
// PROPERTY that makes the fix correct rather than the fix itself: the shell's
// reservation and the banner's own painted geometry are derived from one set of
// constants, and the reservation is the height BELOW the status bar. Reserving
// the full painted height would push every page down by the status-bar inset a
// second time, because the pages already start below it.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/design_tokens.dart';
import 'package:guvenlik_app/widgets/connectivity_banner.dart';

void main() {
  group('MP-72-031 — the offline banner reserves the space it paints', () {
    testWidgets('reserved height is the padded content row at ANY text scale', (
      tester,
    ) async {
      for (final double scale in <double>[1.0, 1.3, 1.5, 2.0]) {
        late BuildContext ctx;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Builder(
              builder: (BuildContext c) {
                ctx = c;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        final double content = ConnectivityBanner.contentHeightFor(ctx);
        expect(
          ConnectivityBanner.reservedHeightFor(ctx),
          ConnectivityBanner.verticalPadding * 2 + content,
          reason:
              'the shell reserves this number; if it stops being the banner\'s '
              'own geometry the two drift apart and the overlap returns',
        );
        expect(
          content,
          greaterThanOrEqualTo(
            ConnectivityBanner.labelFontSize *
                scale *
                ConnectivityBanner.labelLineHeightFactor,
          ),
          reason:
              'CERT2-03: a fixed 16 dp row clipped the label at 1.5x. The row '
              'must be at least as tall as the scaled line box.',
        );
        expect(ConnectivityBanner.reservedHeightFor(ctx), greaterThan(0));
      }
    });

    testWidgets('at text scale 1.0 the icon is still the floor', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (BuildContext c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        ConnectivityBanner.contentHeightFor(ctx),
        IconSizes.dense,
        reason:
            'the fix must not move a single pixel at the default scale: the '
            'leading glyph is still the tallest child there (13 x 1.2 = 15.6 '
            'against a 16 dp icon)',
      );
    });

    testWidgets('the banner paints status-bar inset PLUS the reserved height', (
      tester,
    ) async {
      const double inset = 48;
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(viewPadding: EdgeInsets.only(top: inset)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: _BannerHarness(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final Finder padding = find
          .descendant(
            of: find.byType(_BannerHarness),
            matching: find.byType(Padding),
          )
          .first;
      final EdgeInsets resolved =
          tester.widget<Padding>(padding).padding.resolve(TextDirection.ltr);

      expect(
        resolved.top,
        inset + ConnectivityBanner.verticalPadding,
        reason:
            'the banner pushes its content below the status bar; the inset is '
            'NOT part of what the shell reserves',
      );
      expect(resolved.bottom, ConnectivityBanner.verticalPadding);
      expect(
        resolved.top +
            ConnectivityBanner.contentHeightFor(
              tester.element(find.byType(_PaddingProbe)),
            ) +
            resolved.bottom -
            inset,
        ConnectivityBanner.reservedHeightFor(
          tester.element(find.byType(_PaddingProbe)),
        ),
        reason:
            'painted height below the status bar must equal exactly what the '
            'shell reserves, or the page is either overlapped or over-indented',
      );
    });

    // The original test pinned the banner's own geometry and nothing else, so
    // the half of the fix that actually removes the overlap -- the SHELL
    // reserving the space -- was never asserted. A source contract rather than
    // a render: mounting MainNavigation pulls in get_it, connectivity and four
    // real pages, and this is the one fact that has to stay true (CERT2-03).
    test('the shell reserves the banner height while offline', () {
      final String shell = File(
        'lib/screens/main_navigation.dart',
      ).readAsStringSync();

      expect(
        shell.contains('ConnectivityBanner.reservedHeightFor(context)'),
        isTrue,
        reason:
            'the shell must reserve the banner geometry from the banner itself; '
            'a hard-coded number is how the two drifted apart before',
      );
      expect(
        RegExp(r'top:\s*_isOffline').hasMatch(shell),
        isTrue,
        reason: 'the reservation must be conditional on the offline state',
      );
      expect(
        shell.contains('ConnectivityBanner.reservedHeight,'),
        isFalse,
        reason:
            'the fixed-scale constant no longer exists; using it would pin the '
            'reservation at text scale 1.0 while the banner grew',
      );
    });
  });
}

/// Mirrors how the shell mounts the banner: an overlay pinned to the top.
class _BannerHarness extends StatelessWidget {
  const _BannerHarness();

  @override
  Widget build(BuildContext context) => const Stack(
    children: <Widget>[
      SizedBox.expand(),
      Positioned(top: 0, left: 0, right: 0, child: _PaddingProbe()),
    ],
  );
}

/// The banner's padding is what carries the geometry, so the probe reproduces
/// exactly that expression rather than re-deriving a number.
class _PaddingProbe extends StatelessWidget {
  const _PaddingProbe();

  @override
  Widget build(BuildContext context) {
    final double statusBarInset = MediaQuery.viewPaddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(
        top: statusBarInset + ConnectivityBanner.verticalPadding,
        bottom: ConnectivityBanner.verticalPadding,
      ),
      child: SizedBox(height: ConnectivityBanner.contentHeightFor(context)),
    );
  }
}
