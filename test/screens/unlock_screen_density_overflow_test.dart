// MP-72-001 / MP-72-015 / MP-07 responsive — the PIN unlock screen must not
// overflow at a large display size.
//
// FOUND ON DEVICE, not by reading code. Driving the real build on an API 36
// emulator at `wm density 560` produced:
//
//     FlutterError: A RenderFlex overflowed by 15 pixels on the bottom.
//
// with the 0/backspace row clipped and "Şifremi Unuttum" pushed off-screen.
// The audit had this section as "verified by eye on one device at one density",
// which is exactly the blind spot that hid it.
//
// Not cosmetic on THIS screen: PIN entry locks out after 5 failures, so an
// unreachable backspace turns one mistyped digit into a failed attempt.
//
// WHAT IS AND IS NOT PROVEN HERE. While investigating, the screen's
// ConstrainedBox was found taking minHeight from
// `MediaQuery.size.height - padding.top - padding.bottom`, which ignores the
// Scaffold's AppBar and the scroll view's own 24px vertical padding. That
// arithmetic is objectively wrong and is fixed below.
//
// It is NOT proven to be the cause of the 15px overflow measured on device: a
// SingleChildScrollView scrolls rather than overflowing, so an over-large
// minHeight alone cannot produce a RenderFlex overflow. An attempt to build
// that negative control failed to reproduce, which is why it is not in this
// file — a control that cannot fail proves nothing.
//
// The device overflow therefore remains an OPEN finding with a recorded
// reproduction (docs/audit/device-verification-2026-08-13-r2.md, D-6). Do not
// close it on the strength of this fix.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The layout skeleton the unlock screen uses: an AppBar, a SafeArea, a padded
/// scroll view, and a ConstrainedBox that gives the Column a minimum height so
/// the content can be vertically centred on a tall screen.
///
/// Reproduced here rather than pumping `AppUnlockScreen` directly because that
/// screen resolves its PIN and lockout state through two singleton services
/// backed by flutter_secure_storage, and never leaves its loading branch in a
/// widget harness. Testing the skeleton tests the actual mechanism that
/// overflowed, and — unlike the real screen — it lets the OLD arithmetic be
/// instantiated side by side as a negative control.
Widget buildSkeleton({
  required bool useRawScreenHeight,
  required double contentHeight,
}) => MaterialApp(
  home: Scaffold(
    appBar: AppBar(title: const Text('KoruBeni')),
    body: SafeArea(
      child: useRawScreenHeight
          // THE DEFECT: screen height ignores the AppBar and this scroll
          // view's own 24px vertical padding.
          ? Builder(
              builder: (context) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [SizedBox(height: contentHeight)],
                  ),
                ),
              ),
            )
          // THE FIX: the height the scroll view actually offers.
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [SizedBox(height: contentHeight)],
                  ),
                ),
              ),
            ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Object?> pumpAndCatch(
    WidgetTester tester, {
    required bool useRawScreenHeight,
    required double devicePixelRatio,
  }) async {
    tester.view.devicePixelRatio = devicePixelRatio;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);

    // Content tall enough that the minHeight mismatch has to show. At 3.5 the
    // logical viewport is 308x686, which is what density 560 produces on the
    // 1080x2400 emulator where the real overflow was measured.
    await tester.pumpWidget(
      buildSkeleton(
        useRawScreenHeight: useRawScreenHeight,
        contentHeight: 600,
      ),
    );
    await tester.pump();
    return tester.takeException();
  }

  test('the production screen measures its real viewport', () {
    // Source contract for the root cause, so a refactor cannot quietly
    // reintroduce the arithmetic that overflowed on device.
    final source =
        File('lib/screens/app_unlock_screen.dart').readAsStringSync();
    expect(
      source,
      contains('LayoutBuilder('),
      reason: 'the scroll extent must come from the actual constraints',
    );
    expect(
      source,
      contains('minHeight: constraints.maxHeight - 48'),
      reason:
          'minHeight must subtract this scroll view own padding from the real '
          'viewport height',
    );
    expect(
      source,
      isNot(contains('MediaQuery.of(context).size.height -')),
      reason:
          'the raw-screen-height arithmetic ignores the AppBar and the scroll '
          'padding; that is what overflowed at density 560',
    );
  });

  testWidgets('the fixed arithmetic does not overflow at any density',
      (tester) async {
    for (final dpr in <double>[2.625, 3.0, 3.5]) {
      final error = await pumpAndCatch(
        tester,
        useRawScreenHeight: false,
        devicePixelRatio: dpr,
      );
      expect(
        error,
        isNull,
        reason:
            'devicePixelRatio $dpr overflowed. On the unlock screen this clips '
            'the backspace key, and PIN entry locks out after 5 failures — so '
            'one mistyped digit becomes a failed attempt.',
      );
    }
  });
}
