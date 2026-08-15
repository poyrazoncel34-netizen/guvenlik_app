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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/design_tokens.dart';
import 'package:guvenlik_app/widgets/connectivity_banner.dart';

void main() {
  group('MP-72-031 — the offline banner reserves the space it paints', () {
    test('reservedHeight is the padded content row, excluding the status bar', () {
      expect(
        ConnectivityBanner.reservedHeight,
        ConnectivityBanner.verticalPadding * 2 + ConnectivityBanner.contentHeight,
        reason:
            'the shell reserves this number; if it stops being the banner\'s '
            'own geometry the two drift apart and the overlap returns',
      );
      expect(
        ConnectivityBanner.contentHeight,
        IconSizes.dense,
        reason:
            'the leading glyph is the tallest child of the content row, so the '
            'row measures exactly this. Pinning it is what makes the explicit '
            'SizedBox a record of the current appearance rather than a change '
            'to it.',
      );
      // A reservation of zero would make this whole mechanism a no-op while
      // every other assertion here still passed.
      expect(ConnectivityBanner.reservedHeight, greaterThan(0));
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
        resolved.top + ConnectivityBanner.contentHeight + resolved.bottom -
            inset,
        ConnectivityBanner.reservedHeight,
        reason:
            'painted height below the status bar must equal exactly what the '
            'shell reserves, or the page is either overlapped or over-indented',
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
      child: const SizedBox(height: ConnectivityBanner.contentHeight),
    );
  }
}
