// MP-26-008 / FIR-07 -- the gate chain is a property of CONSTRUCTION ORDER, so
// the set of construction sites is the security argument.
//
// `lib/screens/auth_gate.dart` returned `const MainNavigation()` with no gate in
// front of it. It had zero consumers, so it was unreachable rather than
// exploitable -- but it was a self-describing bypass one import away from use,
// and nothing in the repository would have noticed if someone had used it. The
// file is deleted. This test is what stops the next one.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files allowed to build the post-gate tab shell, and the gate markers that
/// must appear BEFORE every construction in that file.
const _approvedSites = <String, List<String>>{
  // Every branch sits after the consent -> onboarding -> PIN decision.
  'lib/screens/splash_screen.dart': ['legalAccepted', '_hasConfiguredPin'],
  // Reached only from the onboarding completion handler.
  'lib/screens/onboarding_screen.dart': ['onCompleted'],
};

const _declaration = 'lib/screens/main_navigation.dart';

String _stripComments(String src) => src
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  late List<({String file, int line, String head})> sites;

  setUpAll(() {
    sites = <({String file, int line, String head})>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path;
      if (path == _declaration) continue;
      final src = _stripComments(entity.readAsStringSync());
      for (final match in RegExp(r'\bMainNavigation\(\)').allMatches(src)) {
        final head = src.substring(0, match.start);
        sites.add((
          file: path,
          line: head.split('\n').length,
          head: head,
        ));
      }
    }
  });

  test('the census is not vacuous', () {
    expect(sites, isNotEmpty,
        reason: 'if nothing constructs the tab shell, this file is asserting '
            'over an empty set and proves nothing');
    expect(File(_declaration).existsSync(), isTrue);
  });

  test('only approved production files construct the tab shell', () {
    final unapproved = sites
        .where((s) => !_approvedSites.containsKey(s.file))
        .map((s) => '${s.file}:${s.line}')
        .toList();
    expect(unapproved, isEmpty,
        reason: 'a construction outside the gate chain is a ready-made bypass, '
            'reachable or not: $unapproved');
  });

  test('every construction sits after its own gate decision', () {
    final premature = <String>[];
    for (final site in sites) {
      final markers = _approvedSites[site.file];
      if (markers == null) continue;
      for (final marker in markers) {
        if (!site.head.contains(marker)) {
          premature.add('${site.file}:${site.line} (missing "$marker")');
        }
      }
    }
    expect(premature, isEmpty,
        reason: 'the gate must be decided before the shell is built: $premature');
  });

  test('the deleted bypass stays deleted', () {
    expect(File('lib/screens/auth_gate.dart').existsSync(), isFalse);
    final references = <String>[];
    for (final root in <String>['lib', 'test']) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('main_navigation_construction_sites_test.dart')) {
          continue;
        }
        if (entity.readAsStringSync().contains('AuthGate')) {
          references.add(entity.path);
        }
      }
    }
    expect(references, isEmpty,
        reason: 'a dangling reference means the file was removed but something '
            'still expects it: $references');
  });

  test('the splash gate chain still reads consent -> onboarding -> PIN', () {
    final splash = _stripComments(
      File('lib/screens/splash_screen.dart').readAsStringSync(),
    );
    final consent = splash.indexOf('UnifiedConsentScreen');
    final onboarding = splash.indexOf('OnboardingScreen');
    final pin = splash.indexOf('AppUnlockScreen');
    final shell = splash.lastIndexOf('const MainNavigation()');
    expect(consent, isNot(-1));
    expect(onboarding, greaterThan(consent));
    expect(pin, greaterThan(onboarding));
    expect(shell, greaterThan(pin),
        reason: 'the unconditional branch must be the LAST option, after every '
            'gate has been consulted');
  });
}
