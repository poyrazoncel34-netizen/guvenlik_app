// MP-12-017: screen titles must be exposed as headings, so a screen-reader user
// can navigate by heading instead of swiping through every control.
//
// The argument has two halves and both are asserted here:
//
//   1. 21 of the 22 screens put their title in an `AppBar`, and Flutter's
//      AppBar marks its title `header: true` on Android. That is a FRAMEWORK
//      behaviour this app depends on, so it is pinned rather than assumed — a
//      Flutter upgrade that dropped it would otherwise silently remove headings
//      from every screen at once.
//   2. `home_page.dart` is the one screen with no AppBar. Its greeting and its
//      section heading are marked explicitly.
//
// What this does NOT prove: what TalkBack actually announces, or in what order.
// That needs hardware and is tracked in EXTERNAL_LAUNCH_BLOCKERS.md (E8).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppBar exposes its title as a heading on Android', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: null,
          body: SizedBox.shrink(),
        ),
      ),
    );
    // Precondition: with no AppBar there is no heading, so a later positive
    // result cannot come from some unrelated node in the tree.
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.header == true,
      ),
      findsNothing,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          appBar: AppBar(title: const Text('Ayarlar')),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    final semantics = tester.getSemantics(find.text('Ayarlar'));
    expect(
      semantics.flagsCollection.isHeader,
      isTrue,
      reason:
          'This app relies on AppBar for the heading on 21 of 22 screens. If '
          'this ever goes red, those screens lost their headings and each one '
          'needs an explicit Semantics(header: true).',
    );
    handle.dispose();
  });

  // Files with no heading of their own, each for a stated reason. This is an
  // allow-list, not a suppression: adding a real screen here would be exactly
  // the "mark it N/A because it is inconvenient" move the audit policy forbids.
  const noHeadingOfTheirOwn = <String, String>{
    'lib/screens/main_navigation.dart':
        'Tab shell. It hosts screens that carry their own headings and renders '
        'only nav labels; a heading here would announce above the real one.',
    'lib/screens/auth_gate.dart':
        'Pure router widget — contains no Text at all.',
    'lib/screens/splash_screen.dart':
        'Transient brand screen with no navigable content; it is replaced '
        'before a screen reader could navigate it by heading.',
    'lib/screens/legal/onboarding_legal_flow.dart':
        'Four-line re-export file; it renders nothing.',
  };

  test('every screen either has an AppBar or marks its title explicitly', () {
    final screens = Directory('lib/screens')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(
      screens,
      isNotEmpty,
      reason: 'harness precondition: screens must be discoverable',
    );

    final missing = <String>[];
    for (final screen in screens) {
      final source = screen.readAsStringSync();
      final hasAppBar = source.contains('AppBar(');
      final marksHeader = source.contains('header: true');
      if (!hasAppBar && !marksHeader &&
          !noHeadingOfTheirOwn.containsKey(screen.path)) {
        missing.add(screen.path);
      }
    }

    // The allow-list must stay honest: an entry that no longer applies (the
    // file grew an AppBar, or was deleted) has to be removed rather than left
    // as standing permission.
    for (final entry in noHeadingOfTheirOwn.entries) {
      final file = File(entry.key);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'stale allow-list entry: ${entry.key} no longer exists',
      );
      final source = file.readAsStringSync();
      expect(
        source.contains('AppBar(') || source.contains('header: true'),
        isFalse,
        reason:
            '${entry.key} now HAS a heading; remove it from the allow-list so '
            'the exemption does not outlive its reason.',
      );
    }

    expect(
      missing,
      isEmpty,
      reason:
          'A screen with neither an AppBar nor an explicit '
          'Semantics(header: true) exposes no heading at all to a screen '
          'reader.',
    );
  });

  test('the home screen marks its own title and section heading', () {
    // Home is the exception: no AppBar, so the marking has to be explicit.
    final source = File('lib/screens/home_page.dart').readAsStringSync();
    expect(
      source,
      isNot(contains('appBar:')),
      reason:
          'harness precondition: if home ever grows an AppBar this test is '
          'asserting the wrong thing and must be revisited.',
    );
    expect(
      RegExp(
        r'Semantics\(\s*header: true,\s*child: Text\(\s*'
        r"'welcome_greeting'\.tr\(\)",
      ).hasMatch(source),
      isTrue,
      reason: 'the screen title must be a heading',
    );
    expect(
      RegExp(
        r'Semantics\(\s*header: true,\s*child: Text\(\s*'
        r'"quick_actions"\.tr\(\)',
      ).hasMatch(source),
      isTrue,
      reason: 'the quick-actions section heading must be a heading',
    );
  });
}
