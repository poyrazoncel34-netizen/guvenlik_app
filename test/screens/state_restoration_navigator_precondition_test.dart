// WHY THIS APP DOES NOT SET `MaterialApp.restorationScopeId`.
//
// The obvious way to turn on state restoration is one line on the root
// MaterialApp. It was tried, shipped to an API 36 emulator, and it BRICKED the
// app: returning from `adb shell am kill` produced the crash screen and 28
// framework errors within 10 seconds. This file is that failure, reduced to a
// harness so the reason survives as an executable fact instead of a comment
// someone can delete.
//
// THE MECHANISM, in the order it happens:
//
//  1. `WidgetsApp` gives its Navigator `restorationScopeId: 'nav'`
//     UNCONDITIONALLY. So the instant a root restoration bucket exists ABOVE
//     that Navigator, it starts restoring its ROUTE HISTORY too -- there is no
//     way to ask for widget-state restoration only.
//  2. This app's `home:` is SplashScreen, which decides where the user belongs
//     (consent / onboarding / unlock / home) and gets there with
//     `pushReplacement`. That REMOVES the initial route.
//  3. The replacement was pushed with a non-restorable API, so on restore the
//     Navigator drops it -- and the initial route it would have fallen back to
//     is gone as well.
//  4. `assert(_history.isNotEmpty)` fires in navigator.dart, the element tree
//     unwinds, and `_elements.contains(element)` cascades every frame.
//
// THE FIX, and why it is not a workaround. Two shortcuts were measured and
// rejected before this one:
//
//   * pushing the destinations restorably -- rejected on security grounds. The
//     unlock screen was itself reached by `pushReplacement`, i.e. it sat at the
//     BOTTOM of the stack, so a restored route would be re-inserted ABOVE it and
//     the PIN gate would be bypassed by the very feature meant to preserve
//     typing. `test/state_restoration_policy_test.dart` pins that.
//   * moving the bucket BELOW the Navigator with a deep `RootRestorationScope`
//     -- it stopped the crash, and it also stopped restoring: on the device the
//     drafts were still gone after `am kill`. A configuration that avoids
//     crashing by doing nothing is not a fix, so the second case below asserts
//     the restored VALUE, not merely the absence of errors.
//
// What actually works is removing the precondition violation: the app no longer
// destroys its initial route. `/` is the `AppRoot` shell, which swaps its
// top-level destination as STATE. That is what the second case exercises.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for SplashScreen: renders, then replaces the initial route.
class _RouteDestroyingSplash extends StatefulWidget {
  const _RouteDestroyingSplash();
  @override
  State<_RouteDestroyingSplash> createState() => _RouteDestroyingSplashState();
}

class _RouteDestroyingSplashState extends State<_RouteDestroyingSplash> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const _Draft(),
          transitionDuration: const Duration(milliseconds: 200),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('splash'));
}

/// Stands in for [AppRoot]: swaps its destination as STATE, so `/` survives.
class _ShellRoot extends StatefulWidget {
  const _ShellRoot();
  @override
  State<_ShellRoot> createState() => _ShellRootState();
}

class _ShellRootState extends State<_ShellRoot> {
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _destination = const _Draft());
    });
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _destination ?? const Scaffold(body: Text('splash')),
      );
}

/// Stands in for any screen holding unsubmitted input.
class _Draft extends StatefulWidget {
  const _Draft();
  @override
  State<_Draft> createState() => _DraftState();
}

class _DraftState extends State<_Draft> with RestorationMixin {
  final RestorableTextEditingController _text = RestorableTextEditingController();

  @override
  String? get restorationId => 'draft';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_text, 'value');
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextField(key: const Key('field'), controller: _text.value),
      );
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Every framework error raised during the test.
///
/// `tester.takeException()` is not usable here: once more than one exception is
/// recorded it collapses them into a single summary object whose toString does
/// NOT contain the original assertion text, so the case that matters -- WHICH
/// error came first -- becomes unassertable. Installing our own
/// `FlutterError.onError` keeps every error verbatim and in order.
late List<FlutterErrorDetails> collected;

/// Records framework errors for the duration of [body] only.
///
/// The handler is installed INSIDE the test rather than in `setUp`: the test
/// binding installs its own `FlutterError.onError` when the test starts, so a
/// handler set in `setUp` is overwritten before the first pump and silently
/// collects nothing.
Future<void> whileCollectingErrors(Future<void> Function() body) async {
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = collected.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
}

void main() {
  setUp(() => collected = <FlutterErrorDetails>[]);

  testWidgets(
      'PROOF: restorationScopeId on the root MaterialApp breaks a startup that '
      'replaces its initial route', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        restorationScopeId: 'korubeni',
        home: _RouteDestroyingSplash(),
      ),
    );
    await settle(tester);
    await tester.enterText(find.byKey(const Key('field')), 'Ayse');
    await tester.pump();
    expect(collected, isEmpty, reason: 'healthy before the restart');

    await whileCollectingErrors(() async {
      await tester.restartAndRestore();
      await settle(tester);
    });
    // The binding also records them; drain so the test does not fail on
    // "exception was thrown" for the failure it is deliberately provoking.
    while (tester.takeException() != null) {}

    expect(
      collected,
      isNotEmpty,
      reason:
          'This is the configuration that shipped to the emulator and crashed. '
          'If this case ever goes GREEN, Flutter has changed its behaviour and '
          'the root-level scope becomes available again -- revisit '
          'lib/core/widgets/app_restoration_scope.dart rather than assuming it '
          'was always safe.',
    );
    expect(
      collected.first.exception.toString(),
      contains('_history.isNotEmpty'),
      reason:
          'The FIRST failure must be the Navigator refusing an empty restored '
          'history. Everything after it is fallout; naming the head of the '
          'chain is what makes this evidence rather than a screenshot.',
    );
  });

  testWidgets(
      'the shipped shell keeps `/` alive: it restores the draft and raises no '
      'framework error',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        // Exactly as lib/main.dart ships it: root scope ON, and a `home:` that
        // is a SHELL rather than a route that replaces itself.
        restorationScopeId: 'korubeni',
        home: _ShellRoot(),
      ),
    );
    await settle(tester);
    await tester.enterText(find.byKey(const Key('field')), 'Ayse');
    await tester.pump();

    await whileCollectingErrors(() async {
      await tester.restartAndRestore();
      await settle(tester);
    });

    expect(
      collected.map((e) => e.exception.toString()).toList(),
      isEmpty,
      reason: 'the shipped configuration must survive the same restart',
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('field'))).controller?.text,
      'Ayse',
      reason:
          'and it must actually restore the draft -- a configuration that '
          'merely avoids crashing by doing nothing would pass the error check '
          'above while failing the user.',
    );
  });
}
