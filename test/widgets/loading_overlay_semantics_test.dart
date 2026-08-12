// A blocking overlay that says nothing is, to a screen-reader user,
// indistinguishable from an app that has frozen. These tests pin the two
// properties that make it legible: it announces itself (liveRegion) and it
// hides the tree it is covering, so focus cannot wander behind the scrim.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/widgets/loading_overlay.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool isLoading,
    String? message,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // The child must fill the body: LoadingOverlay is a Stack, so a
          // zero-height child would make the overlay's own column overflow --
          // a harness artifact, not a production layout.
          body: LoadingOverlay(
            isLoading: isLoading,
            message: message,
            child: const SizedBox.expand(
              child: Center(child: Text('covered content')),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('announces itself as a live region while loading', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, isLoading: true, message: 'Yükleniyor');

    final node = tester.getSemantics(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
    );
    expect(node.label, contains('Yükleniyor'));
    handle.dispose();
  });

  testWidgets('hides the covered tree so focus cannot wander behind the scrim', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, isLoading: true, message: 'Yükleniyor');

    // The content is still in the widget tree (the overlay is a Stack), but it
    // must not be reachable by assistive technology while the scrim is up.
    expect(find.text('covered content'), findsOneWidget);
    expect(
      find.bySemanticsLabel('covered content'),
      findsNothing,
      reason: 'A modal scrim must not leak the tree it covers to TalkBack.',
    );
    handle.dispose();
  });

  testWidgets('adds no semantics noise when not loading', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, isLoading: false);

    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
      findsNothing,
    );
    expect(find.bySemanticsLabel('covered content'), findsOneWidget);
    handle.dispose();
  });
}
