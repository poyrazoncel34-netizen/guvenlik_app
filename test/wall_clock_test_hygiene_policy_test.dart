import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drift catcher for wall-clock-coupled tests.
///
/// Why this exists
/// ---------------
/// `SubscriptionAccessState` deliberately splits its surface in two:
///
///   * the SAFETY decision (`entitlementDecision`, `canUsePaidSafetyFeature`)
///     checks only the PRESENCE of the two entitlement keys, never the clock,
///     so a wrong device clock can never remove SOS from a subscriber; and
///   * the BILLING decision (`canUseNonEmergencyPaidFeature` and friends)
///     resolves the 7-day offline grace window against the REAL wall clock
///     unless the caller passes an explicit `now:`.
///
/// That asymmetry is the policy, and it is correct at runtime. It is a trap in
/// tests. A test that pins `now` to a calendar date pins only HALF of its own
/// scenario: the anchor keeps drifting further into the past every day the
/// suite is not run, until "3 days offline" quietly means "grace expired".
///
/// This has now happened twice:
///   * 2026-08-14, in `subscription_readiness_state_test.dart`, where scenario
///     F2's "24h of grace left" became "24h of grace expired"; and
///   * 2026-08-20, in `offline_sos_entitlement_policy_test.dart` scenario 2 and
///     `subscription_readiness_state_test.dart` scenario N, which failed on
///     their own with no code change in between.
///
/// The second occurrence is the reason this file exists. The first was fixed by
/// rewriting one time base and leaving two hardcoded dates behind in the same
/// file, which is precisely the kind of partial fix a comment cannot enforce.
///
/// A third case was latent rather than red: scenario K pinned a FUTURE anchor
/// (`DateTime(2026, 8, 23, 12)`) to test a rolled-back device clock. On
/// 2026-08-23 that date stops being in the future, so the case would have
/// started failing, and after 2026-08-30 it would have gone GREEN again while
/// testing nothing of the sort. A silently self-disabling anti-forgery test is
/// worse than a red one.
///
/// What this does NOT catch, stated plainly
/// ---------------------------------------
/// `_stripComments` removes everything after `//` on a line, including a `//`
/// that sits inside a string literal. A URL in a string therefore truncates the
/// rest of that line, so a violation written AFTER a URL on the SAME line is
/// missed. Measured on 2026-08-20: not currently active -- no clock-coupled
/// member and no executable date literal is lost this way anywhere in `test/`.
///
/// This is deliberately not fixed. A string-aware scanner has to model Dart's
/// `'''` multi-line strings, and this repository embeds Dart samples inside
/// them -- the negative control below is itself such a sample. Getting that
/// wrong turns a silent miss into a FALSE POSITIVE, which is the worse
/// direction for a drift catcher: a red test that should be green teaches
/// people to weaken the rule. The miss direction leaves the real failing test
/// as the backstop, which is how this defect was found in the first place.
///
/// The rule
/// --------
/// A test file must not combine a hardcoded calendar date with a grace-bounded
/// member used WITHOUT an explicit `now:`. Passing `now:` fully injects the
/// clock and is always allowed; deriving anchors from `DateTime.now()` is
/// always allowed. Only the combination is banned.
void main() {
  group('wall-clock test hygiene', () {
    test('no test pins a calendar date under a clock-reading member', () {
      final offenders = <String>[];

      for (final file in _testSources()) {
        if (file.path.endsWith('wall_clock_test_hygiene_policy_test.dart')) {
          continue;
        }
        final findings = _violations(file.readAsStringSync());
        if (findings.isNotEmpty) {
          offenders.add('${file.path}: ${findings.join(', ')}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These tests anchor a scenario to a fixed calendar date while '
            'reading a member that resolves the offline-grace window against '
            'the real wall clock. The scenario therefore changes meaning as '
            'the suite ages and will fail on a date nobody chose.\n'
            'Fix: derive the time base from DateTime.now() and express every '
            'anchor relatively (now.subtract(...) / now.add(...)), or pass an '
            'explicit now: to the member.\n'
            'Offenders:\n  ${offenders.join('\n  ')}',
      );
    });

    test('NEGATIVE CONTROL: the detector fires on the 2026-08-20 defect', () {
      // Scenario 2 of offline_sos_entitlement_policy_test.dart as it stood on
      // the day it failed.
      const reintroduced = '''
        void main() {
          final now = DateTime(2026, 8, 13, 12);
          test('offline 3 days', () {
            final s = offlineSubscriber(const Duration(days: 3), now: now);
            expect(s.canUseNonEmergencyPaidFeature, isTrue);
          });
        }
      ''';
      expect(
        _violations(reintroduced),
        isNotEmpty,
        reason: 'the detector must catch the exact defect it was built for',
      );

      // And the repaired form must be accepted, or the rule would just ban
      // testing the grace window at all.
      const repaired = '''
        void main() {
          final now = DateTime.now();
          test('offline 3 days', () {
            final s = offlineSubscriber(const Duration(days: 3), now: now);
            expect(s.canUseNonEmergencyPaidFeature, isTrue);
          });
        }
      ''';
      expect(_violations(repaired), isEmpty);

      // A pinned date is fine when the clock is fully injected.
      const injected = '''
        void main() {
          final now = DateTime(2026, 8, 13, 12);
          test('boundary', () {
            expect(state.canArmWithinOfflineGrace(now: now), isTrue);
          });
        }
      ''';
      expect(_violations(injected), isEmpty);

      // A date mentioned only in a comment is documentation, not an anchor.
      const commented = '''
        void main() {
          // This used to be DateTime(2026, 8, 13, 12) and that was a time bomb.
          final now = DateTime.now();
          test('x', () => expect(s.canUseNonEmergencyPaidFeature, isTrue));
        }
      ''';
      expect(_violations(commented), isEmpty);
    });

    test('no new injectable-clock member enters lib/ unnoticed', () {
      // The detector knows about ONE service. That is a deliberate scope, not
      // an oversight -- but it is only safe while the set of services that can
      // resolve a window against the wall clock stays the set it was written
      // for. Pinning the FILES (not the semantics) costs nothing and forces a
      // human to ask "does the detector need widening?" the moment a new one
      // appears. Same idiom as PINNED_OVERRIDES in
      // scripts/verify_resolution_classification.py: an addition becomes a
      // visible diff instead of a silent gap.
      const known = <String>{
        'lib/core/services/countdown_clock.dart',
        'lib/core/services/offline_queue_service.dart',
        'lib/core/services/rehearsal_record_service.dart',
        'lib/core/services/subscription_access_state.dart',
        'lib/screens/safety_timeline_screen.dart',
      };
      final found = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('?? DateTime.now()'))
          .map((f) => f.path)
          .toSet();
      expect(
        found,
        known,
        reason:
            'A service gained or lost an injectable clock. If it can resolve a '
            'window against DateTime.now(), decide whether tests anchoring it '
            'to a calendar date need the same protection as '
            'SubscriptionAccessState, then update this set on purpose.',
      );
    });

    test('the clock-coupled member list is still complete', () {
      // `_clockMethods` is hand-maintained. It stays honest only while
      // `subscription_access_state.dart` has exactly the two injectable-clock
      // fallbacks it has today. A third one means a new member can read the
      // wall clock without this policy knowing about it.
      final source = File(
        'lib/core/services/subscription_access_state.dart',
      ).readAsStringSync();
      final fallbacks = 'now ?? DateTime.now()'.allMatches(source).length;
      expect(
        fallbacks,
        2,
        reason:
            'A grace-bounded member was added or removed. Update _clockGetters '
            "/ _clockMethods in this file to match, then update this pin. Do "
            'not just change the number.',
      );
    });
  });
}

/// Members that resolve the offline-grace window against the wall clock.
/// Plain getters cannot take a `now`, so they are always coupled.
const _clockGetters = <String>[
  'canUseNonEmergencyPaidFeature',
  'nonEmergencyEntitlementDecision',
];

/// Methods that accept an optional `now:`. Coupled only when it is omitted.
/// Ordered longest-first so `remainingOfflineGraceHours` is matched before its
/// prefix `remainingOfflineGrace`.
const _clockMethods = <String>[
  'canArmWithinOfflineGrace',
  'remainingOfflineGraceHours',
  'remainingOfflineGrace',
];

Iterable<File> _testSources() => Directory('test')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// Returns the coupled members used under a hardcoded calendar date, or an
/// empty list when the file is clean.
List<String> _violations(String source) {
  final code = _stripComments(source);
  if (!RegExp(r'DateTime\(\s*\d{4}\s*,').hasMatch(code)) return const [];

  final found = <String>{};
  for (final getter in _clockGetters) {
    if (code.contains(getter)) found.add(getter);
  }
  for (final method in _clockMethods) {
    for (final match in RegExp(
      '${RegExp.escape(method)}\\(([^)]*)',
    ).allMatches(code)) {
      if (!(match.group(1) ?? '').contains('now:')) {
        found.add('$method() without now:');
      }
    }
  }
  return found.toList()..sort();
}

/// Comments describe history; only executable code anchors a scenario.
String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .map((line) => line.replaceAll(RegExp(r'//.*$'), ''))
    .join('\n');
